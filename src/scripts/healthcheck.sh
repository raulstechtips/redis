#!/bin/sh
set -eu
# shellcheck source=src/scripts/common.sh
. /usr/local/lib/redis/common.sh
load_password
port=6379
[ "${1:-redis}" != sentinel ] || port=26379
[ "$(redis_cli 127.0.0.1 "$port" PING)" = PONG ] || exit 1
if [ "${2:-live}" = ready ]; then
    if [ "${1:-redis}" = sentinel ]; then
        case "$(redis_cli 127.0.0.1 "$port" SENTINEL CKQUORUM "$MASTER_NAME")" in
            OK*) exit 0 ;;
            *) exit 1 ;;
        esac
    fi
    info=$(redis_cli 127.0.0.1 "$port" INFO replication | tr -d '\r')
    case "$info" in
        *role:master*) exit 0 ;;
        *master_link_status:up*) exit 0 ;;
        *) exit 1 ;;
    esac
fi
