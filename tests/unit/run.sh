#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
. ./src/scripts/common.sh

for source in src/scripts/*.sh src/config/*.conf; do
    cmp "$source" "charts/files/${source#src/}"
done
printf 'PASS packaged runtime matches canonical sources\n'

assert_equal() {
    [ "$1" = "$2" ] || {
        printf 'Expected <%s>, got <%s>\n' "$1" "$2" >&2
        exit 1
    }
}

assert_equal '"normal"' "$(config_quote normal)"
assert_equal '"a\"b\\c"' "$(config_quote 'a"b\c')"
printf 'PASS configuration quoting\n'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
printf 'unit-test-password' > "$tmp/password"
PASSWORD_FILE=$tmp/password
load_password
assert_equal unit-test-password "$REDISCLI_AUTH"
: > "$tmp/password"
if (load_password) 2>/dev/null; then
    printf 'Empty password accepted\n' >&2
    exit 1
fi
printf 'line1\nline2' > "$tmp/password"
if (load_password) 2>/dev/null; then
    printf 'Multiline password accepted\n' >&2
    exit 1
fi
printf 'PASS password validation\n'

SENTINEL_HOSTS='s0 s1 s2'
DATA_HOSTS='redis-0 redis-1 redis-2'
MASTER_NAME=mymaster
SENTINEL_MAJORITY=2
redis_cli() {
    case "$1" in
        s0|s1) printf 'redis-1\n6379\n' ;;
        s2) printf 'redis-0\n6379\n' ;;
    esac
}
assert_equal redis-1 "$(discover_primary)"
redis_cli() {
    [ "$1" = s0 ] || return 1
    printf 'redis-0\n6379\n'
}
assert_equal '' "$(discover_primary)"
redis_cli() { printf 'outside-host\n6379\n'; }
assert_equal '' "$(discover_primary)"
redis_cli() { printf 'redis-0\n26379\n'; }
assert_equal '' "$(discover_primary)"
redis_cli() {
    case "$1" in
        s0) printf 'redis-0\n6379\n' ;;
        s1) printf 'redis-1\n6379\n' ;;
        s2) printf 'redis-2\n6379\n' ;;
    esac
}
assert_equal '' "$(discover_primary)"
printf 'PASS primary discovery requires a valid majority\n'

TLS_ENABLED=false
assert_equal 'port 6379' "$(tls_config 6379)"
TLS_ENABLED=true
tls=$(tls_config 26379)
case "$tls" in
    *'port 0
tls-port 26379'*'tls-replication yes'*) ;;
    *) printf 'Invalid TLS configuration\n' >&2; exit 1 ;;
esac
printf 'PASS TLS configuration\n'
printf 'All custom Redis unit tests passed\n'
