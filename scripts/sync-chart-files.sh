#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# src/ is authoritative. Commit these packaged copies with each runtime change.
mkdir -p charts/files/scripts charts/files/config
cp src/scripts/*.sh charts/files/scripts/
cp src/config/*.conf charts/files/config/
