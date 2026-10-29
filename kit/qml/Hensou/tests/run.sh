#!/usr/bin/env bash
# Run inside the pinned Qt dependency environment, on Aka in this workflow.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
qml_root=$(realpath "$here/../..")
# qmltestrunner may be an unwrapped qtdeclarative binary even when qt6.env
# supplies its merged prefix. Keep both that module tree and inherited paths.
qt_qml=${QT_QML_ROOT:-"$(dirname "$(command -v qmltestrunner)")/../lib/qt-6/qml"}
export QML2_IMPORT_PATH="$qml_root:$qt_qml:${QML2_IMPORT_PATH:-}"
export QML_IMPORT_PATH="$qml_root:$qt_qml:${QML_IMPORT_PATH:-}"
export QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen}
export QT_QUICK_BACKEND=${QT_QUICK_BACKEND:-software}
exec qmltestrunner -input "$here" -o -,txt "$@"
