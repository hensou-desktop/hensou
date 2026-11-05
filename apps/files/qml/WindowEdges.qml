import QtQuick

// Resize handles along a frameless window's edges. The compositor runs the
// resize (startSystemResize), so it works the same under any scale.
Item {
    id: root
    required property var window
    property real grip: 5
    readonly property bool resizable: window.visibility === Window.Windowed

    component Edge: MouseArea {
        property int edges: 0
        enabled: root.resizable
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: root.window.startSystemResize(edges)
    }
    Edge { edges: Qt.LeftEdge; x: 0; y: root.grip; width: root.grip; height: root.height - 2 * root.grip; cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.RightEdge; x: root.width - root.grip; y: root.grip; width: root.grip; height: root.height - 2 * root.grip; cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.TopEdge; x: root.grip; y: 0; width: root.width - 2 * root.grip; height: root.grip; cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.BottomEdge; x: root.grip; y: root.height - root.grip; width: root.width - 2 * root.grip; height: root.grip; cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.TopEdge | Qt.LeftEdge; x: 0; y: 0; width: root.grip; height: root.grip; cursorShape: Qt.SizeFDiagCursor }
    Edge { edges: Qt.TopEdge | Qt.RightEdge; x: root.width - root.grip; y: 0; width: root.grip; height: root.grip; cursorShape: Qt.SizeBDiagCursor }
    Edge { edges: Qt.BottomEdge | Qt.LeftEdge; x: 0; y: root.height - root.grip; width: root.grip; height: root.grip; cursorShape: Qt.SizeBDiagCursor }
    Edge { edges: Qt.BottomEdge | Qt.RightEdge; x: root.width - root.grip; y: root.height - root.grip; width: root.grip; height: root.grip; cursorShape: Qt.SizeFDiagCursor }
}
