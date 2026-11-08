#!/bin/sh
set -eu
umask 077
# shellcheck source=src/scripts/common.sh
. /usr/local/lib/redis/common.sh
load_password

primary=''
if [ "$MODE" = sentinel ]; then
    attempt=0
    while [ "$attempt" -lt 60 ]; do
        primary=$(discover_primary)
        [ -z "$primary" ] || break
        attempt=$((attempt + 1))
        sleep 2
    done
    [ -n "$primary" ] || die "No Sentinel majority agreed on the primary"
fi

{
    cat /etc/redis/redis.conf
    tls_config 6379
    printf 'requirepass %s\nmasterauth %s\n' "$(config_quote "$REDISCLI_AUTH")" "$(config_quote "$REDISCLI_AUTH")"
    printf 'maxmemory %s\nmaxmemory-policy %s\nappendonly %s\n' "$MAXMEMORY" "$EVICTION_POLICY" "$APPENDONLY"
    if [ "$MODE" = sentinel ]; then
        printf 'replica-announce-ip %s\nreplica-announce-port 6379\n' "$POD_HOST"
        if [ "$primary" != "$POD_HOST" ]; then
            printf 'replicaof %s 6379\n' "$primary"
        fi
    fi
} > /run/redis/redis.conf
unset REDISCLI_AUTH
exec redis-server /run/redis/redis.conf
