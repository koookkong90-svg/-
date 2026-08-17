#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

RESTORE_HAS_STOPPED_APPS=0
RESTORE_TEMP_ENV=""

usage() {
    cat >&2 <<'EOF'
Usage:
  bash scripts/backup/restore-backup.sh verify  <backup-directory>
  bash scripts/backup/restore-backup.sh restore <backup-directory>
EOF
}

cleanup_restore() {
    local exit_code="$?"
    trap - EXIT INT TERM

    if [[ -n "$RESTORE_TEMP_ENV" && -e "$RESTORE_TEMP_ENV" ]]; then
        rm -f -- "$RESTORE_TEMP_ENV"
    fi

    if (( exit_code != 0 && RESTORE_HAS_STOPPED_APPS == 1 )); then
        backup_warn "restore failed after application services were stopped"
        backup_warn "application services were intentionally left stopped; inspect the error and the pre-restore backup before proceeding"
    fi

    exit "$exit_code"
}

verify_command() {
    local bundle_dir="$1"

    bundle_dir="$(backup_verify_bundle "$bundle_dir")"
    backup_log "backup verification succeeded"
    printf '%s\n' "$bundle_dir"
}

project_has_existing_docker_state() {
    local logical_name expected_volume

    if [[ -n "$(docker ps -a --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" --format '{{.ID}}' | head -n 1)" ]]; then
        return 0
    fi

    for logical_name in mysql_data static-files browser_data; do
        if [[ -n "$(docker volume ls \
            --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" \
            --filter "label=com.docker.compose.volume=$logical_name" \
            --format '{{.Name}}' | head -n 1)" ]]; then
            return 0
        fi

        # Also fail closed for an old/unlabelled volume with the exact Compose-derived name.
        expected_volume="${COMPOSE_PROJECT_NAME}_${logical_name}"
        if docker volume inspect "$expected_volume" >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

assert_existing_mysql_config_matches() {
    local incoming_env="$1"
    local key current_value incoming_value

    for key in MYSQL_ROOT_PASSWORD MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD; do
        if ! current_value="$(backup_env_raw_value "$COMPOSE_ENV_FILE" "$key")"; then
            backup_die "existing .env does not define $key; refusing an automatic in-place restore"
        fi
        if ! incoming_value="$(backup_env_raw_value "$incoming_env" "$key")"; then
            backup_die "backup .env does not define $key; refusing an automatic in-place restore"
        fi
        [[ "$current_value" == "$incoming_value" ]] \
            || backup_die "existing and backup .env differ for $key; credentials are not changed automatically"
    done
}

create_pre_restore_backup() {
    backup_log "existing project data detected; creating a complete pre-restore safety backup"
    BACKUP_CONFIG_FILE="$BACKUP_CONFIG_FILE" \
    BACKUP_LOCK_HELD=1 \
    BACKUP_SKIP_RETENTION=1 \
        bash "$SCRIPT_DIR/create-backup.sh"
    backup_log "pre-restore safety backup completed"
}

save_env_only() {
    local timestamp destination

    timestamp="$(date '+%Y%m%d_%H%M%S')"
    destination="$LOCAL_BACKUP_DIR/pre-restore-env_${timestamp}"
    [[ ! -e "$destination" ]] || backup_die "pre-restore environment backup already exists"
    mkdir -m 700 -- "$destination"
    install -m 600 -- "$COMPOSE_ENV_FILE" "$destination/.env"
    printf 'This directory contains only the pre-restore environment file; no Docker data existed.\n' \
        > "$destination/README"
    chmod 600 -- "$destination/README"
    backup_log "saved the existing environment file before replacement: $destination"
}

confirm_restore() {
    local confirmation=""
    local expected="RESTORE $BACKUP_TOOL_PROJECT"

    backup_warn "restore will replace MySQL, static-files, browser_data, and the root .env"
    if [[ "${BACKUP_RESTORE_CONFIRM:-}" == "$expected" ]]; then
        return 0
    fi
    [[ -t 0 ]] || backup_die "interactive confirmation is required (type: $expected)"
    printf 'Type "%s" to continue: ' "$expected" >&2
    IFS= read -r confirmation
    [[ "$confirmation" == "$expected" ]] || backup_die "restore confirmation did not match"
}

stop_application_services() {
    local services=()
    local service container_id

    for service in frontend scheduler websocket backend-web; do
        container_id="$("${BACKUP_COMPOSE[@]}" ps -a -q "$service" 2>/dev/null || true)"
        if [[ -n "$container_id" && "$(docker inspect --format '{{.State.Running}}' "$container_id")" == "true" ]]; then
            services+=("$service")
        fi
    done

    if (( ${#services[@]} > 0 )); then
        backup_log "stopping application services before restore: ${services[*]}"
        RESTORE_HAS_STOPPED_APPS=1
        "${BACKUP_COMPOSE[@]}" stop --timeout 60 "${services[@]}" >/dev/null
    fi
}

install_restored_env() {
    local source_env="$1"

    RESTORE_TEMP_ENV="$(mktemp "$BACKUP_REPO_ROOT/.env.restore.XXXXXX")"
    install -m 600 -- "$source_env" "$RESTORE_TEMP_ENV"
    mv -f -- "$RESTORE_TEMP_ENV" "$COMPOSE_ENV_FILE"
    RESTORE_TEMP_ENV=""
    chmod 600 -- "$COMPOSE_ENV_FILE"
    backup_log "restored the root environment file"
}

restore_named_volume() {
    local service="$1"
    local destination="$2"
    local logical_name="$3"
    local archive="$4"
    local volume_name image archive_dir archive_name

    volume_name="$(backup_resolve_named_volume "$service" "$destination" "$logical_name")"
    image="$(backup_container_image "$service")"
    archive_dir="$(dirname -- "$archive")"
    archive_name="$(basename -- "$archive")"

    docker run --rm --pull never --network none --read-only \
        --cap-drop ALL --security-opt no-new-privileges \
        --entrypoint sh "$image" -ec \
        'command -v find >/dev/null 2>&1 && command -v tar >/dev/null 2>&1'

    backup_log "replacing volume contents: $logical_name"
    docker run --rm --pull never --network none --read-only \
        --cap-drop ALL --security-opt no-new-privileges \
        --volume "$volume_name:/restore-target" \
        --volume "$archive_dir:/restore-source:ro" \
        --entrypoint sh "$image" -ec '
            target=/restore-target
            archive="/restore-source/$1"
            if [ ! -d "$target" ] || [ -L "$target" ]; then
                printf "%s\n" "unsafe restore target" >&2
                exit 1
            fi
            if [ ! -f "$archive" ] || [ -L "$archive" ]; then
                printf "%s\n" "unsafe restore archive" >&2
                exit 1
            fi
            find "$target" -xdev -depth -mindepth 1 -delete
            tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$target"
        ' sh "$archive_name"
}

wait_for_healthy_service() {
    local service="$1"
    local timeout_seconds="${2:-180}"
    local deadline container_id status

    deadline=$((SECONDS + timeout_seconds))
    while (( SECONDS < deadline )); do
        container_id="$("${BACKUP_COMPOSE[@]}" ps -q "$service" 2>/dev/null || true)"
        if [[ -n "$container_id" ]]; then
            status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")"
            if [[ "$status" == "healthy" || "$status" == "running" ]]; then
                return 0
            fi
        fi
        sleep 2
    done

    backup_die "service did not become healthy in time: $service"
}

run_mysql_admin_action() {
    local action="$1"

    "${BACKUP_COMPOSE[@]}" exec -T mysql sh -ec '
        umask 077
        auth_file="$(mktemp)"
        trap "rm -f -- \"$auth_file\"" EXIT HUP INT TERM
        action="$1"

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

        case "$action" in
            reset)
                mysql --defaults-extra-file="$auth_file" \
                    --default-character-set=utf8mb4 \
                    --execute="DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`; CREATE DATABASE \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
                ;;
            import)
                mysql --defaults-extra-file="$auth_file" \
                    --binary-mode=1 \
                    --default-character-set=utf8mb4 \
                    "$MYSQL_DATABASE"
                ;;
            count)
                mysql --defaults-extra-file="$auth_file" \
                    --batch --skip-column-names \
                    --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE();" \
                    "$MYSQL_DATABASE"
                ;;
            check)
                mysqlcheck --defaults-extra-file="$auth_file" "$MYSQL_DATABASE" >/dev/null
                ;;
            *)
                printf "%s\n" "invalid MySQL restore action" >&2
                exit 1
                ;;
        esac
    ' sh "$action"
}

restore_mysql() {
    local sql_file="$1"
    local table_count

    backup_log "starting MySQL only"
    "${BACKUP_COMPOSE[@]}" up -d --no-deps mysql >/dev/null
    wait_for_healthy_service mysql 240

    run_mysql_admin_action reset

    backup_log "importing the MySQL logical dump"
    gzip -dc -- "$sql_file" | run_mysql_admin_action import

    table_count="$(run_mysql_admin_action count | tr -d '[:space:]')"
    [[ "$table_count" =~ ^[0-9]+$ && "$table_count" -gt 0 ]] \
        || backup_die "restored database contains no tables"

    run_mysql_admin_action check
    backup_log "MySQL restore verification passed ($table_count tables)"
}

start_application_stack() {
    backup_log "starting Redis without restoring or clearing redis_data"
    "${BACKUP_COMPOSE[@]}" up -d --no-deps redis >/dev/null
    wait_for_healthy_service redis 120

    backup_log "starting application services"
    "${BACKUP_COMPOSE[@]}" up -d --no-deps backend-web >/dev/null
    wait_for_healthy_service backend-web 240
    "${BACKUP_COMPOSE[@]}" up -d --no-deps websocket >/dev/null
    wait_for_healthy_service websocket 240
    "${BACKUP_COMPOSE[@]}" up -d --no-deps scheduler >/dev/null
    wait_for_healthy_service scheduler 240
    "${BACKUP_COMPOSE[@]}" up -d --no-deps frontend >/dev/null

    RESTORE_HAS_STOPPED_APPS=0
}

restore_command() {
    local requested_bundle="$1"
    local bundle_dir bundle_name timestamp sql_file
    local had_docker_state=0 had_env=0

    # This verification is deliberately completed before Docker or target data is touched.
    bundle_dir="$(backup_verify_bundle "$requested_bundle")"
    bundle_name="$(basename -- "$bundle_dir")"
    timestamp="$(backup_bundle_timestamp "$bundle_name")"
    sql_file="$bundle_dir/mysql/database_${timestamp}.sql.gz"

    backup_require_commands docker realpath flock find date gzip tar sha256sum install awk mktemp
    backup_load_config
    backup_prepare_root
    backup_acquire_lock
    trap cleanup_restore EXIT INT TERM

    [[ -f "$COMPOSE_FILE" && ! -L "$COMPOSE_FILE" ]] \
        || backup_die "Compose file not found or unsafe: $COMPOSE_FILE"
    docker compose version >/dev/null 2>&1 \
        || backup_die "Docker Compose v2 is not available"

    confirm_restore

    if [[ -e "$COMPOSE_ENV_FILE" || -L "$COMPOSE_ENV_FILE" ]]; then
        [[ -f "$COMPOSE_ENV_FILE" && ! -L "$COMPOSE_ENV_FILE" ]] \
            || backup_die "existing root .env is not a safe regular file"
        had_env=1
    fi
    project_has_existing_docker_state && had_docker_state=1

    if (( had_docker_state == 1 )); then
        (( had_env == 1 )) \
            || backup_die "existing project containers or volumes were found but the current .env is unavailable; safe backup is impossible"
        assert_existing_mysql_config_matches "$bundle_dir/config/.env"
        backup_init_compose
        stop_application_services
        create_pre_restore_backup
    elif (( had_env == 1 )); then
        save_env_only
    fi

    install_restored_env "$bundle_dir/config/.env"
    backup_init_compose

    # Build deterministically on a freshly cloned server before any volume or database is replaced.
    "${BACKUP_COMPOSE[@]}" build backend-web websocket scheduler frontend

    # Create service containers and their declared volumes without starting business services.
    "${BACKUP_COMPOSE[@]}" create --no-recreate backend-web websocket >/dev/null

    # Validate every destructive target before replacing any volume or database contents.
    backup_resolve_named_volume mysql /var/lib/mysql mysql_data >/dev/null
    backup_resolve_named_volume backend-web /app/static static-files >/dev/null
    backup_resolve_named_volume websocket /app/browser_data browser_data >/dev/null

    restore_named_volume \
        backend-web /app/static static-files \
        "$bundle_dir/volumes/static-files.tar.gz"
    restore_named_volume \
        websocket /app/browser_data browser_data \
        "$bundle_dir/volumes/browser_data.tar.gz"

    restore_mysql "$sql_file"
    start_application_stack

    backup_log "restore completed; perform the documented application-level checks"
    "${BACKUP_COMPOSE[@]}" ps
}

main() {
    local command_name="${1:-}"
    local bundle_path="${2:-}"

    [[ -n "$command_name" && -n "$bundle_path" && $# -eq 2 ]] || {
        usage
        exit 2
    }

    case "$command_name" in
        verify) verify_command "$bundle_path" ;;
        restore) restore_command "$bundle_path" ;;
        *) usage; exit 2 ;;
    esac
}

main "$@"
