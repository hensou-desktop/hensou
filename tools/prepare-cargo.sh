#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils git
set -euo pipefail
test "$(hostname -s)" = aka
if [ "${1:-}" != --inside ]; then
    exec nix develop --builders '' --max-jobs 1 --cores 2 -c bash "$0" --inside
fi
sha=$(git rev-parse HEAD)
prep=$(mktemp -d /tmp/hensou-cargo-prep.XXXXXX)
cp -a . "$prep/source"
cd "$prep/source"
cargo generate-lockfile
cargo fmt --all
nixfmt flake.nix nix/fonts.nix
ruff check --isolated --select I --fix tests/demo/run.py tests/demo/pointer.py
ruff format --isolated tests/demo/run.py tests/demo/pointer.py
out=/tmp/hensou-foundation-416d014746da/evidence/build-prep-$sha
mkdir -p "$out"
cp Cargo.lock "$out/Cargo.lock"
git diff --binary > "$out/format.patch"
printf 'PREPARATION_ONLY source=%s artifacts=%s\n' "$sha" "$out"
