#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils
set -euo pipefail
test "$(hostname -s)" = aka
if [ "${1:-}" != --inside ]; then
    exec nix develop --builders '' --max-jobs 1 --cores 2 -c bash "$0" --inside
fi
export CARGO_TARGET_DIR=/tmp/hensou-foundation-416d014746da/build-target
cargo fmt --all -- --check
cargo test --package hensou-theme-state --locked
cargo check --package hensou-qt-host --package hensou-demo --locked
cargo clippy --package hensou-theme-state --package hensou-qt-host --package hensou-demo --all-targets --locked -- -D warnings
