#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
helm dependency build --skip-refresh tests/dependency
helm template harbor tests/dependency -n harbor --set cache.tls.enabled=false > "$tmp/harbor.yaml"
test "$(yq 'select(.kind == "StatefulSet") | .metadata.name' "$tmp/harbor.yaml")" = harbor-cache-node
test "$(yq 'select(.kind == "Certificate") | .metadata.name' "$tmp/harbor.yaml")" = ""
test "$(yq 'select(.kind == "NetworkPolicy") | .spec.ingress[0].from[0].podSelector.matchLabels."app.kubernetes.io/instance"' "$tmp/harbor.yaml")" = harbor
helm template infisical tests/dependency -n infisical > "$tmp/infisical.yaml"
test "$(yq 'select(.kind == "Certificate") | .spec.secretName' "$tmp/infisical.yaml")" = infisical-cache-tls
test "$(yq 'select(.kind == "StatefulSet") | .metadata.name' "$tmp/infisical.yaml")" = infisical-cache-node
helm template disabled tests/dependency --set cache.enabled=false > "$tmp/disabled.yaml"
test -z "$(yq 'select(.kind != null) | .kind' "$tmp/disabled.yaml")"
printf 'Dependency chart checks passed\n'
