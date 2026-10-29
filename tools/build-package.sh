#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils git
set -euo pipefail
test "$(hostname -s)" = aka
attribute=${1:?one package attribute}
case "$attribute" in hensou-qml|hensou-demo|chicagoflf|w95fa-grid) ;; *) exit 2 ;; esac
sha=$(git rev-parse HEAD)
exec nix build --builders '' --max-jobs 1 --cores 2 --print-out-paths \
    --out-link "/tmp/hensou-foundation-416d014746da/evidence/package-$attribute-$sha" ".#$attribute"
