#!/usr/bin/env bash

repo_resolve_url() {
    if [ -n "${REPO_URL:-}" ]; then
        printf '%s\n' "$REPO_URL"
        return 0
    fi

    case "${REPO_PROTOCOL:-}" in

        local)
            if [ -z "${REPO_LOCAL_PATH:-}" ]; then
                echo "error: REPO_LOCAL_PATH is not set" >&2
                return 1
            fi

            printf '%s\n' "$REPO_LOCAL_PATH"
            ;;

        https)
            if [ -z "${REPO_OWNER:-}" ] || [ -z "${REPO_NAME:-}" ]; then
                echo "error: REPO_OWNER/REPO_NAME is not set" >&2
                return 1
            fi

            printf 'https://github.com/%s/%s.git\n' \
                "$REPO_OWNER" \
                "$REPO_NAME"
            ;;

        ssh)
            if [ -z "${REPO_OWNER:-}" ] || [ -z "${REPO_NAME:-}" ]; then
                echo "error: REPO_OWNER/REPO_NAME is not set" >&2
                return 1
            fi

            local host="${SSH_HOST:-github.com}"

            printf 'git@%s:%s/%s.git\n' \
                "$host" \
                "$REPO_OWNER" \
                "$REPO_NAME"
            ;;

        *)
            echo "error: unknown REPO_PROTOCOL: ${REPO_PROTOCOL:-}" >&2
            return 1
            ;;
    esac
}
