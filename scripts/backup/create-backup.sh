#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STAGING_DIR=""
FINAL_DIR=""
QUIESCED_SERVICES=()

resume_quiesced_services() {
    if (( ${#QUIESCED_SERVICES[@]} == 0 )); then
        return 0
    fi

    backup_log "starting services paused for the backup: ${QUIESCED_SERVICES[*]}"
    "${BACKUP_COMPOSE[@]}" start "${QUIESCED_SERVICES[@]}" >/dev/null
    QUIESCED_SERVICES=()
}

cleanup_create_backup() {
    local exit_code="$?"
    trap - EXIT INT TERM

    if ! resume_quiesced_services; then
        backup_warn "failed to restart one or more services after backup"
        exit_code=1
    fi

    if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
        if ! backup_remove_incomplete_dir "$STAGING_DIR"; then
            backup_warn "could not safely remove incomplete backup directory: $STAGING_DIR"
        fi
    fi

    exit "$exit_code"
}

service_is_running() {
    local service="$1"
    local container_id

    container_id="$(backup_compose_container_id "$service")"
    backup_assert_container_identity "$container_id" "$service"
    [[ "$(docker inspect --format '{{.State.Running}}' "$container_id")" == "true" ]]
}

quiesce_writers() {
    local service

    [[ "$BACKUP_QUIESCE_SERVICES" == "true" ]] || return 0
    for service in backend-web websocket scheduler; do
        if service_is_running "$service"; then
            QUIESCED_SERVICES+=("$service")
        fi
    done

    if (( ${#QUIESCED_SERVICES[@]} > 0 )); then
        backup_log "briefly stopping write services for a consistent snapshot: ${QUIESCED_SERVICES[*]}"
        "${BACKUP_COMPOSE[@]}" stop --timeout 60 "${QUIESCED_SERVICES[@]}" >/dev/null
    fi
}

assert_mysql_ready_for_dump() {
    local container_id health_status

    container_id="$(backup_compose_container_id mysql)"
    backup_assert_container_identity "$container_id" mysql
    [[ "$(docker inspect --format '{{.State.Running}}' "$container_id")" == "true" ]] \
        || backup_die "MySQL container is not running"

    health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id")"
    [[ "$health_status" == "healthy" ]] \
        || backup_die "MySQL container is not healthy (status: $health_status)"

    "${BACKUP_COMPOSE[@]}" exec -T mysql sh -ec \
        'command -v mysqldump >/dev/null 2>&1 && command -v sed >/dev/null 2>&1 && mysqldump --version >/dev/null 2>&1' \
        || backup_die "mysqldump is not available inside the MySQL service"
}

dump_mysql() {
    local output_file="$1"

    backup_log "creating MySQL logical dump"
    "${BACKUP_COMPOSE[@]}" exec -T mysql sh -ec '
        umask 077
        auth_file="$(mktemp)"
        trap "rm -f -- \"$auth_file\"" EXIT HUP INT TERM

        case "$MYSQL_DATABASE" in
            ""|*[!A-Za-z0-9_]*)
                printf "%s\n" "invalid MYSQL_DATABASE identifier" >&2
                exit 1
                ;;
        esac

        escaped_password="$(printf "%s" "$MYSQL_ROOT_PASSWORD" | sed -e "s/\\\\/\\\\\\\\/g" -e "s/\"/\\\\\"/g")"
        printf "[client]\nuser=root\npassword=\"%s\"\nhost=127.0.0.1\nprotocol=tcp\n" \
            "$escaped_password" > "$auth_file"
        unset escaped_password
        chmod 600 "$auth_file"

        mysqldump --defaults-extra-file="$auth_file" \
            --single-transaction \
            --quick \
            --routines \
            --events \
            --triggers \
            --hex-blob \
            --no-tablespaces \
            --set-gtid-purged=OFF \
            --default-character-set=utf8mb4 \
            "$MYSQL_DATABASE"
    ' | gzip -c > "$output_file"

    [[ -s "$output_file" ]] || backup_die "MySQL dump is empty"
    gzip -t -- "$output_file" || backup_die "MySQL dump gzip verification failed"
}

write_checksums_and_complete_marker() {
    local bundle_dir="$1"
    local timestamp="$2"

    (
        cd "$bundle_dir"
        sha256sum \
            "mysql/database_${timestamp}.sql.gz" \
            "config/.env" \
            "volumes/static-files.tar.gz" \
            "volumes/browser_data.tar.gz" > SHA256SUMS
        sha256sum --strict -c SHA256SUMS >/dev/null
    )

    {
        printf 'project=%s\n' "$BACKUP_TOOL_PROJECT"
        printf 'format=%s\n' "$BACKUP_FORMAT_VERSION"
        printf 'timestamp=%s\n' "$timestamp"
        printf 'created_at=%s\n' "$(date --iso-8601=seconds)"
    } > "$bundle_dir/COMPLETE"

    find "$bundle_dir" -type d -exec chmod 700 -- {} +
    find "$bundle_dir" -type f -exec chmod 600 -- {} +
}

main() {
    local timestamp bundle_name sql_file

    backup_require_commands realpath flock find date stat gzip tar sha256sum mktemp install awk
    backup_load_config
    backup_prepare_root
    backup_acquire_lock
    backup_init_compose
    trap cleanup_create_backup EXIT INT TERM

    assert_mysql_ready_for_dump

    # Resolve and validate the exact current project volumes before any service is stopped.
    backup_resolve_named_volume backend-web /app/static static-files >/dev/null
    backup_resolve_named_volume websocket /app/browser_data browser_data >/dev/null
    backup_container_image backend-web >/dev/null
    backup_container_image websocket >/dev/null

    timestamp="$(date '+%Y%m%d_%H%M%S')"
    bundle_name="${BACKUP_TOOL_PROJECT}_backup_${timestamp}"
    FINAL_DIR="$LOCAL_BACKUP_DIR/$bundle_name"
    [[ ! -e "$FINAL_DIR" ]] || backup_die "backup directory already exists: $FINAL_DIR"

    STAGING_DIR="$(mktemp -d "$LOCAL_BACKUP_DIR/.incomplete_${bundle_name}.XXXXXX")"
    mkdir -p -- "$STAGING_DIR/mysql" "$STAGING_DIR/config" "$STAGING_DIR/volumes"

    quiesce_writers

    sql_file="$STAGING_DIR/mysql/database_${timestamp}.sql.gz"
    dump_mysql "$sql_file"

    backup_log "copying the root environment file without printing its contents"
    install -m 600 -- "$COMPOSE_ENV_FILE" "$STAGING_DIR/config/.env"

    backup_log "archiving static-files"
    backup_archive_volume \
        backend-web /app/static static-files \
        "$STAGING_DIR/volumes/static-files.tar.gz"
    backup_validate_tar "$STAGING_DIR/volumes/static-files.tar.gz"

    backup_log "archiving browser_data"
    backup_archive_volume \
        websocket /app/browser_data browser_data \
        "$STAGING_DIR/volumes/browser_data.tar.gz"
    backup_validate_tar "$STAGING_DIR/volumes/browser_data.tar.gz"

    # Minimize the maintenance window; checksum work does not require services to stay stopped.
    resume_quiesced_services

    write_checksums_and_complete_marker "$STAGING_DIR" "$timestamp"
    mv -- "$STAGING_DIR" "$FINAL_DIR"
    STAGING_DIR=""

    backup_prune_local
    backup_log "backup completed successfully"
    printf '%s\n' "$FINAL_DIR"
}

main "$@"
