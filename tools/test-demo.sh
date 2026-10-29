#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils
set -euo pipefail
test "$(hostname -s)" = aka
if [ "${1:-}" != --inside ]; then
    exec nix develop --builders '' --max-jobs 1 --cores 2 -c bash "$0" --inside
fi
export CARGO_TARGET_DIR=/tmp/hensou-foundation-416d014746da/build-target
node tests/demo/layout.test.js
cargo build --package hensou-demo --locked
export HENSOU_QML_IMPORT_PATH="$PWD/kit/qml"
export QML_IMPORT_PATH="$PWD/kit/qml:$QML_IMPORT_PATH"
python3 tests/demo/run.py "$CARGO_TARGET_DIR/debug/hensou-demo-tests"
