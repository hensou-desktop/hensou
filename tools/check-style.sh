#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils
set -euo pipefail
test "$(hostname -s)" = aka
if [ "${1:-}" != --inside ]; then
    exec nix develop --builders '' --max-jobs 1 --cores 2 -c bash "$0" --inside
fi
nixfmt --check flake.nix nix/fonts.nix
ruff check tests/demo/run.py tests/demo/pointer.py
ruff format --check tests/demo/run.py tests/demo/pointer.py
shellcheck tools/build-native.sh tools/prepare-cargo.sh tools/test-demo.sh tools/check-style.sh tools/build-package.sh tools/test-package.sh
