#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils
# Files: Rust formatting, unit tests, Clippy and the pure QML model tests.
# Run under the shared heavy-job wrapper on Aka, from the checkout.
set -euo pipefail
test "$(hostname -s)" = aka
if [ "${1:-}" != --inside ]; then
    exec nix develop --builders '' --max-jobs 1 --cores 2 -c bash "$0" --inside
fi
export CARGO_TARGET_DIR=/tmp/hensou-p35/target-app
node tests/files/model.test.js
cargo fmt --package hensou-files -- --check
cargo test --package hensou-files --locked
cargo clippy --package hensou-files --all-targets --locked -- -D warnings
ruff check --config tests/demo/ruff.toml tests/files/run.py
ruff format --config tests/demo/ruff.toml --check tests/files/run.py
nixfmt --check flake.nix
shellcheck --shell=bash tools/check-files.sh tools/test-files.sh tools/test-files-package.sh
