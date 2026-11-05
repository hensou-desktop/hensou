#!/usr/bin/env nix-shell
#! nix-shell -i bash -p qt6.qtdeclarative qt6.qtbase
# PROTOTYPE — render the LCARS desktop states into ../shots/desktop-*.png.
# Usage: ./render.sh [state ...]    states: normal notify switch dual
#        ./render.sh run [state]    interactive window
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
decl="$(dirname "$(dirname "$(readlink -f "$(command -v qml)")")")"
export QML_IMPORT_PATH="$decl/lib/qt-6/qml"
export QT_PLUGIN_PATH="$decl/lib/qt-6/plugins"
[ -f "$here/../fonts/Antonio.ttf" ] || "$here/../render.sh" A 400 300 >/dev/null  # fetches the font

if [ "${1:-}" = "run" ]; then exec qml "$here/DesktopMain.qml" -- --state "${2:-normal}"; fi

export QT_QPA_PLATFORM=offscreen
states=("$@"); [ ${#states[@]} -gt 0 ] || states=(normal notify switch dual)
for s in "${states[@]}"; do
  qml "$here/DesktopMain.qml" -- --state "$s" --out "$here/../shots/desktop-$s.png" 2>&1 | grep -v '^$' || true
  echo "shots/desktop-$s.png"
done
qml "$here/DesktopMain.qml" -- --state normal --w 1280 --h 800 --out "$here/../shots/desktop-small.png" 2>&1 | grep -v '^$' || true
echo "shots/desktop-small.png"
