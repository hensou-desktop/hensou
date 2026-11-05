import QtQuick

// A caption button: 16 x 14 u, raised, with Marlett's glyph (close "×",
// help "?" or minimize "_"). Pressed: sunken and the glyph 1 u down and right.
Item {
    id: root

    property string glyph: "close"     // "close", "help" or "minimize"
    property bool showPressed: false
    property var scheme: null

    signal clicked

    readonly property real u: 2 / WindowMetrics.ratio(root)
    readonly property bool down: showPressed || (area.pressed && area.containsMouse)

    implicitWidth: MemphisTokens.captionButtonWidth * u
    implicitHeight: MemphisTokens.captionButtonHeight * u

    MemphisBevel {
        anchors.fill: parent
        variant: root.down ? "pressed" : "button"
        scheme: root.scheme
    }
    MemphisIcon {
        name: root.glyph
        color: (root.scheme || MemphisTokens)[root.enabled ? "text" : "gray"]
        x: MemphisTokens.snap((root.width - width) / 2, root.u) + (root.down ? root.u : 0)
        y: MemphisTokens.snap((root.height - height) / 2, root.u) + (root.down ? root.u : 0)
    }
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
