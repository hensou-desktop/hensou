#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils git
set -euo pipefail
test "$(hostname -s)" = aka
if [ "${1:-}" != --inside ]; then
    package=$(nix build --builders '' --max-jobs 1 --cores 2 --no-link --print-out-paths .#hensou-demo)
    exec nix develop --builders '' --max-jobs 1 --cores 2 -c bash "$0" --inside "$package"
fi
package=${2:?wrapped package path}
# Python removes the dev shell's runtime paths before starting either Qt binary.
python3 tests/demo/run.py "$package/bin/hensou-demo-tests" "$package/bin/hensou-demo" --packaged
