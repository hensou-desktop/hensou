#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils
# Files: build the app and its Qt Quick test binary, then run the suite,
# the captures and the real-process checks on a private headless Sway.
# Run under the shared heavy-job wrapper on Aka. HENSOU_FILES_TEST_MODES
# narrows the run (suite, capture, process).
set -euo pipefail
test "$(hostname -s)" = aka
if [ "${1:-}" != --inside ]; then
    # D-Bus (session bus, gdbus) for the StatusNotifierItem checks.
    mapfile -t extra < <(nix build --builders '' --max-jobs 1 --cores 2 --no-link --print-out-paths \
        --inputs-from . nixpkgs#dbus nixpkgs#glib.bin)
    exec nix develop --builders '' --max-jobs 1 --cores 2 -c bash "$0" --inside "${extra[@]}"
fi
shift
for path in "$@"; do PATH="$path/bin:$PATH"; done
export PATH
export CARGO_TARGET_DIR=/tmp/hensou-p35/target-app
cargo build --package hensou-files --locked
export HENSOU_QML_IMPORT_PATH="$PWD/kit/qml"
export QML_IMPORT_PATH="$PWD/kit/qml:$QML_IMPORT_PATH"
python3 tests/files/run.py "$CARGO_TARGET_DIR/debug/hensou-files-tests" "$CARGO_TARGET_DIR/debug/hensou-files"
