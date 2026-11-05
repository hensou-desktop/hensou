#!/usr/bin/env nix-shell
#! nix-shell -i bash -p qt6.qtdeclarative qt6.qtbase
# PROTOTYPE — render every variant across the size ladder into shots/.
# Usage: ./render.sh            (all)   ./render.sh A 1280 800 [data] [menu]   (one)
# Interactive: ./render.sh run [A|B|C]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
qmlbin="$(command -v qml)"
decl="$(dirname "$(dirname "$(readlink -f "$qmlbin")")")"
export QML_IMPORT_PATH="$decl/lib/qt-6/qml"
export QT_PLUGIN_PATH="$decl/lib/qt-6/plugins"

if [ ! -f "$here/fonts/Antonio.ttf" ]; then
  mkdir -p "$here/fonts"
  curl -sfL -o "$here/fonts/Antonio.ttf" \
    'https://github.com/google/fonts/raw/main/ofl/antonio/Antonio%5Bwght%5D.ttf'
fi

if [ "${1:-}" = "run" ]; then
  exec qml "$here/Main.qml" -- --variant "${2:-A}"
fi

export QT_QPA_PLATFORM=offscreen
mkdir -p "$here/shots"

one() { # variant w h data menu
  local name="$1-$2x$3-$4${5:+-menu}"
  qml "$here/Main.qml" -- --variant "$1" --w "$2" --h "$3" --data "$4" \
    ${5:+--menu 1} --out "$here/shots/$name.png" 2>&1 | grep -v '^$' || true
  echo "shots/$name.png"
}

if [ $# -ge 3 ]; then one "$1" "$2" "$3" "${4:-ideal}" "${5:-}"; exit; fi

for v in A B C; do
  for s in 1440x900 960x700 460x860 1400x340; do
    one "$v" "${s%x*}" "${s#*x}" ideal ""
  done
  one "$v" 960 700 empty ""
  one "$v" 1440 900 ideal 1
  one "$v" 460 860 ideal 1
done
