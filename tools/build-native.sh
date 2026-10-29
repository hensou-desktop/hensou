#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils
set -euo pipefail
# Only run on Aka under the run's shared heavy.sh lock, in nix develop.
test "$(hostname -s)" = aka
cargo generate-lockfile
cargo fmt --all
cargo test --package hensou-theme-state --locked
cargo check --package hensou-qt-host --package hensou-demo --locked
cargo clippy --package hensou-theme-state --package hensou-qt-host --package hensou-demo --all-targets --locked -- -D warnings
