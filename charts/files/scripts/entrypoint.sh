#!/bin/sh
set -eu
umask 077
case "${1:-}" in
    redis) exec /usr/local/lib/redis/redis-start.sh ;;
    sentinel) exec /usr/local/lib/redis/sentinel-start.sh ;;
    *) exec "$@" ;;
esac
