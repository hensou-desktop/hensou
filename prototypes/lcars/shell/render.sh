#!/usr/bin/env nix-shell
#! nix-shell -i bash -p qt6.qtdeclarative qt6.qtbase
# PROTOTYPE — render the LCARS shell sweep into ../shots/shell-*.png.
# Usage: ./render.sh [state ...]   ./render.sh run [state]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
decl="$(dirname "$(dirname "$(readlink -f "$(command -v qml)")")")"
export QML_IMPORT_PATH="$decl/lib/qt-6/qml"
export QT_PLUGIN_PATH="$decl/lib/qt-6/plugins"
[ -f "$here/../fonts/Antonio.ttf" ] || "$here/../render.sh" A 400 300 >/dev/null
if [ "${1:-}" = "run" ]; then exec qml "$here/ShellMain.qml" -- --state "${2:-calm}"; fi
export QT_QPA_PLATFORM=offscreen
states=("$@")
[ ${#states[@]} -gt 0 ] || states=(calm warn chord system sound wifi layout find switch glance dictation notify unread critical shutdown dual small)
for s in "${states[@]}"; do
  qml "$here/ShellMain.qml" -- --state "$s" --out "$here/../shots/shell-$s.png" 2>&1 | grep -v '^$' | head -5 || true
  echo "shots/shell-$s.png"
done
