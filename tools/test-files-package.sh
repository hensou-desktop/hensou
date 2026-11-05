#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils git
# Files: build the hensou-files package, then run its wrapped binaries with
# the dev shell's Qt paths cleared. Run under the heavy-job wrapper on Aka.
set -euo pipefail
test "$(hostname -s)" = aka
if [ "${1:-}" != --inside ]; then
    package=$(nix build --builders '' --max-jobs 1 --cores 2 --no-link --print-out-paths .#hensou-files)
    mapfile -t extra < <(nix build --builders '' --max-jobs 1 --cores 2 --no-link --print-out-paths \
        --inputs-from . nixpkgs#dbus nixpkgs#glib.bin)
    exec nix develop --builders '' --max-jobs 1 --cores 2 -c bash "$0" --inside "$package" "${extra[@]}"
fi
package=${2:?wrapped package path}
shift 2
for path in "$@"; do PATH="$path/bin:$PATH"; done
export PATH
test -f "$package/share/applications/hensou-files.desktop"
grep -qx 'MimeType=inode/directory;' "$package/share/applications/hensou-files.desktop"
grep -qx 'Exec=hensou-files %U' "$package/share/applications/hensou-files.desktop"
python3 tests/files/run.py "$package/bin/hensou-files-tests" "$package/bin/hensou-files" --packaged
