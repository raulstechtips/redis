#!/bin/sh

die() {
    printf '%s\n' "$*" >&2
    exit 1
}

load_password() {
    [ -r "${PASSWORD_FILE:-/secrets/password}" ] || die "Password file is not readable"
    REDISCLI_AUTH=$(cat "${PASSWORD_FILE:-/secrets/password}")
    [ -n "$REDISCLI_AUTH" ] || die "Password must not be empty"
    case "$REDISCLI_AUTH" in
        *'
'*|*"$(printf '\r')"*) die "Password must be a single line" ;;
    esac
    export REDISCLI_AUTH
}

# Redis configuration uses double-quoted strings, not shell quoting.
config_quote() {
    printf '%s' "$1" | awk 'BEGIN { ORS=""; printf "\"" }
        { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); printf "%s", $0 }
        END { printf "\"" }'
}

redis_cli() {
    host=$1 port=$2
    shift 2
    if [ "${TLS_ENABLED:-false}" = true ]; then
        timeout 3 redis-cli --no-auth-warning --raw --tls --cacert /tls/ca.crt \
            --cert /tls/tls.crt --key /tls/tls.key -h "$host" -p "$port" "$@"
    else
        timeout 3 redis-cli --no-auth-warning --raw -h "$host" -p "$port" "$@"
    fi
}

tls_config() {
    port=$1
    if [ "${TLS_ENABLED:-false}" = true ]; then
        printf 'port 0\ntls-port %s\ntls-cert-file /tls/tls.crt\ntls-key-file /tls/tls.key\ntls-ca-cert-file /tls/ca.crt\ntls-auth-clients no\ntls-replication yes\n' "$port"
    else
        printf 'port %s\n' "$port"
    fi
}

# Require agreement from a majority of all configured Sentinels. Never promote
# ordinal zero merely because discovery is temporarily unavailable.
discover_primary() {
    votes=''
    for sentinel in $SENTINEL_HOSTS; do
        reply=$(redis_cli "$sentinel" 26379 SENTINEL get-master-addr-by-name "$MASTER_NAME" 2>/dev/null) || continue
        primary=$(printf '%s\n' "$reply" | awk 'NR==1 { print }')
        port=$(printf '%s\n' "$reply" | awk 'NR==2 { print }')
        [ "$port" = 6379 ] || continue
        case " $DATA_HOSTS " in
            *" $primary "*) votes="$votes $primary" ;;
        esac
    done
    printf '%s\n' "$votes" | awk -v required="$SENTINEL_MAJORITY" '
        { for (i=1; i<=NF; i++) count[$i]++ }
        END { for (host in count) if (count[host]>=required) { print host; exit } }'
}
