#!/usr/bin/env bash

# Shared helpers for the local disaster-recovery scripts.
# This file is sourced by create-backup.sh and restore-backup.sh.

BACKUP_TOOL_PROJECT="xianyu-auto-reply"
BACKUP_FORMAT_VERSION="1"
BACKUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_REPO_ROOT="$(cd "$BACKUP_SCRIPT_DIR/../.." && pwd)"
BACKUP_CONFIG_FILE="${BACKUP_CONFIG_FILE:-$BACKUP_REPO_ROOT/backup.env}"
BACKUP_SENTINEL_NAME=".xianyu-auto-reply-backup-root"
BACKUP_SENTINEL_VALUE="xianyu-auto-reply local backup root v1"
BACKUP_BUNDLE_REGEX='^xianyu-auto-reply_backup_[0-9]{8}_[0-9]{6}$'

backup_log() {
    printf '[backup] %s\n' "$*" >&2
}

backup_warn() {
    printf '[backup] WARNING: %s\n' "$*" >&2
}

backup_die() {
    printf '[backup] ERROR: %s\n' "$*" >&2
    exit 1
}

backup_require_commands() {
    local command_name
    for command_name in "$@"; do
        command -v "$command_name" >/dev/null 2>&1 \
            || backup_die "required command not found: $command_name"
    done
}

backup_resolve_path() {
    local value="$1"

    if [[ "$value" == /* ]]; then
        realpath -m -- "$value"
    else
        realpath -m -- "$BACKUP_REPO_ROOT/$value"
    fi
}

backup_load_config() {
    LOCAL_BACKUP_DIR="/var/backups/xianyu-auto-reply"
    LOCAL_RETENTION_DAYS="7"
    COMPOSE_PROJECT_NAME="$BACKUP_TOOL_PROJECT"
    COMPOSE_FILE="./docker-compose.yml"
    COMPOSE_ENV_FILE="./.env"
    BACKUP_QUIESCE_SERVICES="true"

    if [[ -f "$BACKUP_CONFIG_FILE" && ! -L "$BACKUP_CONFIG_FILE" ]]; then
        # backup.env is an administrator-controlled local configuration file.
        # shellcheck source=/dev/null
        source "$BACKUP_CONFIG_FILE"
    elif [[ -e "$BACKUP_CONFIG_FILE" ]]; then
        backup_die "backup config is not a regular file: $BACKUP_CONFIG_FILE"
    fi

    [[ "$COMPOSE_PROJECT_NAME" == "$BACKUP_TOOL_PROJECT" ]] \
        || backup_die "COMPOSE_PROJECT_NAME must be $BACKUP_TOOL_PROJECT"
    [[ "$LOCAL_RETENTION_DAYS" =~ ^[1-9][0-9]*$ ]] \
        || backup_die "LOCAL_RETENTION_DAYS must be an integer of at least 1"
    (( 10#$LOCAL_RETENTION_DAYS <= 3650 )) \
        || backup_die "LOCAL_RETENTION_DAYS is unreasonably large"
    [[ "$BACKUP_QUIESCE_SERVICES" == "true" || "$BACKUP_QUIESCE_SERVICES" == "false" ]] \
        || backup_die "BACKUP_QUIESCE_SERVICES must be true or false"

    COMPOSE_FILE="$(backup_resolve_path "$COMPOSE_FILE")"
    COMPOSE_ENV_FILE="$(backup_resolve_path "$COMPOSE_ENV_FILE")"
    LOCAL_BACKUP_DIR="$(backup_resolve_path "$LOCAL_BACKUP_DIR")"

    [[ "$COMPOSE_FILE" == "$BACKUP_REPO_ROOT/docker-compose.yml" ]] \
        || backup_die "this first version only supports the root docker-compose.yml"
    [[ "$COMPOSE_ENV_FILE" == "$BACKUP_REPO_ROOT/.env" ]] \
        || backup_die "this first version only backs up and restores the root .env"

    [[ "$LOCAL_BACKUP_DIR" != "/" ]] \
        || backup_die "LOCAL_BACKUP_DIR must not be /"
    [[ -z "${HOME:-}" || "$LOCAL_BACKUP_DIR" != "$(realpath -m -- "$HOME")" ]] \
        || backup_die "LOCAL_BACKUP_DIR must not be the home directory"
    [[ "$LOCAL_BACKUP_DIR" != "$BACKUP_REPO_ROOT" && "$LOCAL_BACKUP_DIR" != "$BACKUP_REPO_ROOT/"* ]] \
        || backup_die "LOCAL_BACKUP_DIR must be outside the repository"
}

backup_prepare_root() {
    local sentinel_path="$LOCAL_BACKUP_DIR/$BACKUP_SENTINEL_NAME"
    local first_entry=""

    if [[ -L "$LOCAL_BACKUP_DIR" ]]; then
        backup_die "backup root must not be a symbolic link: $LOCAL_BACKUP_DIR"
    fi

    if [[ ! -e "$LOCAL_BACKUP_DIR" ]]; then
        mkdir -p -- "$LOCAL_BACKUP_DIR"
    fi
    [[ -d "$LOCAL_BACKUP_DIR" && ! -L "$LOCAL_BACKUP_DIR" ]] \
        || backup_die "backup root is not a safe directory: $LOCAL_BACKUP_DIR"
    chmod 700 -- "$LOCAL_BACKUP_DIR"

    if [[ -e "$sentinel_path" ]]; then
        [[ -f "$sentinel_path" && ! -L "$sentinel_path" ]] \
            || backup_die "invalid backup root sentinel: $sentinel_path"
        [[ "$(<"$sentinel_path")" == "$BACKUP_SENTINEL_VALUE" ]] \
            || backup_die "backup root sentinel content does not match this project"
    else
        first_entry="$(find "$LOCAL_BACKUP_DIR" -mindepth 1 -maxdepth 1 -print -quit)"
        [[ -z "$first_entry" ]] \
            || backup_die "refusing to adopt a non-empty directory without the project sentinel: $LOCAL_BACKUP_DIR"
        (umask 077; printf '%s\n' "$BACKUP_SENTINEL_VALUE" > "$sentinel_path")
        chmod 600 -- "$sentinel_path"
    fi
}

backup_acquire_lock() {
    local lock_path="$LOCAL_BACKUP_DIR/.backup.lock"

    if [[ "${BACKUP_LOCK_HELD:-0}" == "1" ]]; then
        { true >&9; } 2>/dev/null \
            || backup_die "BACKUP_LOCK_HELD was set without an inherited lock descriptor"
        return 0
    fi

    exec 9> "$lock_path"
    flock -n 9 || backup_die "another backup or restore process is already running"
    export BACKUP_LOCK_HELD=1
}

backup_init_compose() {
    backup_require_commands docker
    [[ -f "$COMPOSE_FILE" && ! -L "$COMPOSE_FILE" ]] \
        || backup_die "Compose file not found or unsafe: $COMPOSE_FILE"
    [[ -f "$COMPOSE_ENV_FILE" && ! -L "$COMPOSE_ENV_FILE" ]] \
        || backup_die "Compose environment file not found or unsafe: $COMPOSE_ENV_FILE"
    docker compose version >/dev/null 2>&1 \
        || backup_die "Docker Compose v2 is not available"

    BACKUP_COMPOSE=(
        docker compose
        --project-name "$COMPOSE_PROJECT_NAME"
        --project-directory "$BACKUP_REPO_ROOT"
        --file "$COMPOSE_FILE"
        --env-file "$COMPOSE_ENV_FILE"
    )
}

backup_compose_container_id() {
    local service="$1"
    local container_id

    container_id="$("${BACKUP_COMPOSE[@]}" ps -a -q "$service")"
    [[ -n "$container_id" ]] || backup_die "Compose container does not exist for service: $service"
    [[ "$(printf '%s\n' "$container_id" | wc -l | tr -d '[:space:]')" == "1" ]] \
        || backup_die "expected exactly one container for service: $service"
    printf '%s\n' "$container_id"
}

backup_assert_container_identity() {
    local container_id="$1"
    local expected_service="$2"
    local identity

    identity="$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}|{{index .Config.Labels "com.docker.compose.service"}}' "$container_id")"
    [[ "$identity" == "$COMPOSE_PROJECT_NAME|$expected_service" ]] \
        || backup_die "container identity mismatch for service $expected_service"
}

backup_resolve_named_volume() {
    local service="$1"
    local destination="$2"
    local expected_logical_name="$3"
    local container_id mount_data mount_type volume_name source_path labels

    container_id="$(backup_compose_container_id "$service")"
    backup_assert_container_identity "$container_id" "$service"

    mount_data="$(docker inspect --format "{{range .Mounts}}{{if eq .Destination \"$destination\"}}{{printf \"%s|%s|%s\" .Type .Name .Source}}{{end}}{{end}}" "$container_id")"
    [[ -n "$mount_data" ]] \
        || backup_die "required mount $destination was not found on service $service"

    IFS='|' read -r mount_type volume_name source_path <<< "$mount_data"
    [[ "$mount_type" == "volume" && -n "$volume_name" && -n "$source_path" ]] \
        || backup_die "$service:$destination must be a named Docker volume in this first version"

    labels="$(docker volume inspect --format '{{index .Labels "com.docker.compose.project"}}|{{index .Labels "com.docker.compose.volume"}}' "$volume_name")"
    [[ "$labels" == "$COMPOSE_PROJECT_NAME|$expected_logical_name" ]] \
        || backup_die "volume identity mismatch for $service:$destination"

    printf '%s\n' "$volume_name"
}

backup_container_image() {
    local service="$1"
    local container_id image

    container_id="$(backup_compose_container_id "$service")"
    backup_assert_container_identity "$container_id" "$service"
    image="$(docker inspect --format '{{.Image}}' "$container_id")"
    [[ -n "$image" ]] || backup_die "could not resolve image for service: $service"
    printf '%s\n' "$image"
}

backup_archive_volume() {
    local service="$1"
    local destination="$2"
    local logical_name="$3"
    local output_file="$4"
    local volume_name image

    volume_name="$(backup_resolve_named_volume "$service" "$destination" "$logical_name")"
    image="$(backup_container_image "$service")"

    docker run --rm --pull never --network none --read-only \
        --cap-drop ALL --security-opt no-new-privileges \
        --volume "$volume_name:/backup-source:ro" \
        --entrypoint tar "$image" \
        -C /backup-source -czf - . > "$output_file"
}

backup_validate_tar() {
    local archive="$1"
    local entry normalized verbose_line entry_type link_target

    [[ -s "$archive" ]] || backup_die "tar archive is empty: $archive"
    tar -tzf "$archive" >/dev/null \
        || backup_die "tar archive cannot be listed: $archive"

    while IFS= read -r entry; do
        normalized="$entry"
        while [[ "$normalized" == ./* ]]; do
            normalized="${normalized#./}"
        done
        [[ -z "$normalized" || "$normalized" == "." ]] && continue
        [[ "$normalized" != /* && "$normalized" != *\\* ]] \
            || backup_die "unsafe tar path in $archive"
        case "/$normalized/" in
            */../*) backup_die "parent traversal found in tar archive: $archive" ;;
        esac
    done < <(tar -tzf "$archive")

    while IFS= read -r verbose_line; do
        entry_type="${verbose_line:0:1}"
        case "$entry_type" in
            b|c|p|s) backup_die "special file found in tar archive: $archive" ;;
            l|h)
                if [[ "$entry_type" == "l" ]]; then
                    link_target="${verbose_line##* -> }"
                else
                    link_target="${verbose_line##* link to }"
                fi
                [[ "$link_target" != /* ]] \
                    || backup_die "absolute link found in tar archive: $archive"
                case "/$link_target/" in
                    */../*) backup_die "unsafe link found in tar archive: $archive" ;;
                esac
                ;;
        esac
    done < <(tar -tvzf "$archive")
}

backup_bundle_timestamp() {
    local bundle_name="$1"
    printf '%s\n' "${bundle_name#xianyu-auto-reply_backup_}"
}

backup_verify_checksum_manifest() {
    local bundle_dir="$1"
    local timestamp="$2"
    local checksum_file="$bundle_dir/SHA256SUMS"
    local line hash relative_path
    local -A expected=()
    local -A seen=()

    expected["mysql/database_${timestamp}.sql.gz"]=1
    expected["config/.env"]=1
    expected["volumes/static-files.tar.gz"]=1
    expected["volumes/browser_data.tar.gz"]=1

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^([0-9a-f]{64})[[:space:]][[:space:]](.+)$ ]] \
            || backup_die "invalid SHA256SUMS line"
        hash="${BASH_REMATCH[1]}"
        relative_path="${BASH_REMATCH[2]}"
        [[ -n "${expected[$relative_path]+x}" ]] \
            || backup_die "unexpected path in SHA256SUMS: $relative_path"
        [[ -z "${seen[$relative_path]+x}" ]] \
            || backup_die "duplicate path in SHA256SUMS: $relative_path"
        [[ "$relative_path" != /* && "$relative_path" != *'..'* && "$relative_path" != *\\* ]] \
            || backup_die "unsafe path in SHA256SUMS"
        seen["$relative_path"]="$hash"
    done < "$checksum_file"

    [[ "${#seen[@]}" == "${#expected[@]}" ]] \
        || backup_die "SHA256SUMS does not contain the exact required file set"

    for relative_path in "${!expected[@]}"; do
        [[ -n "${seen[$relative_path]+x}" ]] \
            || backup_die "missing path in SHA256SUMS: $relative_path"
    done

    (cd "$bundle_dir" && sha256sum --strict -c SHA256SUMS >/dev/null) \
        || backup_die "SHA-256 verification failed"
}

backup_verify_bundle() {
    local requested_path="$1"
    local bundle_dir bundle_name timestamp sql_file required_file

    backup_require_commands realpath sha256sum gzip tar grep
    [[ -d "$requested_path" && ! -L "$requested_path" ]] \
        || backup_die "backup bundle is not a safe directory: $requested_path"

    bundle_dir="$(realpath -- "$requested_path")"
    bundle_name="$(basename -- "$bundle_dir")"
    [[ "$bundle_name" =~ $BACKUP_BUNDLE_REGEX ]] \
        || backup_die "backup directory name is invalid: $bundle_name"
    timestamp="$(backup_bundle_timestamp "$bundle_name")"
    sql_file="$bundle_dir/mysql/database_${timestamp}.sql.gz"

    for required_file in \
        "$sql_file" \
        "$bundle_dir/config/.env" \
        "$bundle_dir/volumes/static-files.tar.gz" \
        "$bundle_dir/volumes/browser_data.tar.gz" \
        "$bundle_dir/SHA256SUMS" \
        "$bundle_dir/COMPLETE"; do
        [[ -f "$required_file" && ! -L "$required_file" ]] \
            || backup_die "required backup file is missing or unsafe: $required_file"
    done

    [[ -s "$bundle_dir/config/.env" ]] || backup_die "backed-up .env is empty"
    grep -Fxq "project=$BACKUP_TOOL_PROJECT" "$bundle_dir/COMPLETE" \
        || backup_die "COMPLETE marker belongs to a different project"
    grep -Fxq "format=$BACKUP_FORMAT_VERSION" "$bundle_dir/COMPLETE" \
        || backup_die "unsupported backup format"
    grep -Fxq "timestamp=$timestamp" "$bundle_dir/COMPLETE" \
        || backup_die "COMPLETE timestamp does not match the directory name"

    backup_verify_checksum_manifest "$bundle_dir" "$timestamp"
    gzip -t -- "$sql_file" || backup_die "MySQL gzip file is invalid"
    backup_validate_tar "$bundle_dir/volumes/static-files.tar.gz"
    backup_validate_tar "$bundle_dir/volumes/browser_data.tar.gz"

    printf '%s\n' "$bundle_dir"
}

backup_is_safe_complete_bundle() {
    local candidate="$1"
    local root_real candidate_real parent_real bundle_name timestamp required_file

    [[ -d "$candidate" && ! -L "$candidate" ]] || return 1
    root_real="$(realpath -- "$LOCAL_BACKUP_DIR")" || return 1
    candidate_real="$(realpath -- "$candidate")" || return 1
    parent_real="$(dirname -- "$candidate_real")"
    [[ "$parent_real" == "$root_real" ]] || return 1

    bundle_name="$(basename -- "$candidate_real")"
    [[ "$bundle_name" =~ $BACKUP_BUNDLE_REGEX ]] || return 1
    timestamp="$(backup_bundle_timestamp "$bundle_name")"
    [[ -f "$candidate_real/COMPLETE" && ! -L "$candidate_real/COMPLETE" ]] || return 1
    [[ -f "$candidate_real/SHA256SUMS" && ! -L "$candidate_real/SHA256SUMS" ]] || return 1
    grep -Fxq "project=$BACKUP_TOOL_PROJECT" "$candidate_real/COMPLETE" || return 1
    grep -Fxq "format=$BACKUP_FORMAT_VERSION" "$candidate_real/COMPLETE" || return 1
    grep -Fxq "timestamp=$timestamp" "$candidate_real/COMPLETE" || return 1
    for required_file in \
        "$candidate_real/mysql/database_${timestamp}.sql.gz" \
        "$candidate_real/config/.env" \
        "$candidate_real/volumes/static-files.tar.gz" \
        "$candidate_real/volumes/browser_data.tar.gz"; do
        [[ -f "$required_file" && ! -L "$required_file" ]] || return 1
    done
}

backup_prune_local() {
    local cutoff now candidate modified

    [[ "${BACKUP_SKIP_RETENTION:-0}" != "1" ]] || return 0
    now="$(date +%s)"
    cutoff=$((now - 10#$LOCAL_RETENTION_DAYS * 86400))

    while IFS= read -r -d '' candidate; do
        backup_is_safe_complete_bundle "$candidate" || continue
        modified="$(stat -c '%Y' -- "$candidate")" || continue
        if (( modified < cutoff )); then
            backup_log "removing expired complete backup: $(basename -- "$candidate")"
            rm -rf -- "$candidate"
        fi
    done < <(find "$LOCAL_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
}

backup_remove_incomplete_dir() {
    local candidate="$1"
    local root_real candidate_real parent_real bundle_name

    [[ -n "$candidate" && -d "$candidate" && ! -L "$candidate" ]] || return 0
    root_real="$(realpath -- "$LOCAL_BACKUP_DIR")" || return 1
    candidate_real="$(realpath -- "$candidate")" || return 1
    parent_real="$(dirname -- "$candidate_real")"
    bundle_name="$(basename -- "$candidate_real")"
    [[ "$parent_real" == "$root_real" ]] || return 1
    [[ "$bundle_name" == .incomplete_xianyu-auto-reply_backup_* ]] || return 1
    rm -rf -- "$candidate_real"
}

backup_env_raw_value() {
    local env_file="$1"
    local key="$2"

    awk -v wanted="$key" '
        BEGIN { found = 0 }
        /^[[:space:]]*#/ { next }
        {
            line = $0
            sub(/\r$/, "", line)
            if (line ~ "^[[:space:]]*" wanted "[[:space:]]*=") {
                sub("^[[:space:]]*" wanted "[[:space:]]*=", "", line)
                value = line
                found = 1
            }
        }
        END {
            if (found) {
                printf "%s", value
            } else {
                exit 2
            }
        }
    ' "$env_file"
}
