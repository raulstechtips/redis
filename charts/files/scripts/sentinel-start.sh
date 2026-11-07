#!/bin/sh
set -eu
umask 077
# shellcheck source=src/scripts/common.sh
. /usr/local/lib/redis/common.sh
load_password

# Keep Sentinel's identity, election epochs and discovered topology. Refresh
# credentials and chart-controlled settings without resetting failover state.
state=/data/sentinel.conf
{
    cat /etc/redis/sentinel.conf
    tls_config 26379
    printf 'requirepass %s\n' "$(config_quote "$REDISCLI_AUTH")"
    printf 'sentinel announce-ip %s\nsentinel announce-port 26379\n' "$POD_HOST"
    if [ -s "$state" ]; then
        awk -v quorum="$SENTINEL_QUORUM" '
            /^sentinel monitor / { $NF=quorum }
            /^sentinel (myid|monitor|known-replica|known-sentinel|current-epoch|config-epoch|leader-epoch) / { print }
        ' "$state"
    else
        printf 'sentinel monitor %s %s 6379 %s\n' "$MASTER_NAME" "$BOOTSTRAP_PRIMARY" "$SENTINEL_QUORUM"
    fi
    printf 'sentinel auth-pass %s %s\n' "$MASTER_NAME" "$(config_quote "$REDISCLI_AUTH")"
    printf 'sentinel down-after-milliseconds %s %s\n' "$MASTER_NAME" "$DOWN_AFTER_MS"
    printf 'sentinel failover-timeout %s %s\n' "$MASTER_NAME" "$FAILOVER_TIMEOUT_MS"
    printf 'sentinel parallel-syncs %s 1\n' "$MASTER_NAME"
} > /data/sentinel.conf.new
mv /data/sentinel.conf.new "$state"
unset REDISCLI_AUTH
exec redis-server "$state" --sentinel
