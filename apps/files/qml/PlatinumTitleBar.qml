import QtQuick
import Hensou

// A Mac OS 8 document window's title bar: close box at the left, engraved
// stripes either side of the title, the zoom and collapse boxes at the right.
// Stripes and boxes show only in the front window, as on Mac OS. Dragging
// the bar moves the window (the compositor does it); double-clicking it
// collapses the window to its title (WindowShade).
Item {
    id: root
    required property var window
    property string title: window.title
    property bool closable: true
    property bool zoomable: true
    property bool collapsible: true
    signal closeClicked()
    signal zoomClicked()
    signal collapseClicked()
    readonly property real hair: PlatinumTokens.hairFor(WindowMetrics.ratio(root))
    readonly property bool front: window.active
    implicitHeight: 22

    Rectangle { anchors.fill: parent; color: PlatinumTokens.menuSurface }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: root.hair; color: PlatinumTokens.menuEdge }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: root.window.startSystemMove()
        onDoubleClicked: root.collapseClicked()
    }

    component Box: PlatinumBevel {
        id: box
        property bool held: false
        width: 13
        height: 13
        anchors.verticalCenter: parent.verticalCenter
        visible: root.front
        sunken: held
        color: held ? PlatinumTokens.well : PlatinumTokens.raised
    }
    component Stripes: Item {
        height: 9 * root.hair
        anchors.verticalCenter: parent.verticalCenter
        visible: root.front && width > 0
        Repeater {
            model: 3
            Item {
                required property int index
                width: parent.width
                y: index * 3 * root.hair
                height: 2 * root.hair
                Rectangle { width: parent.width; height: root.hair; color: PlatinumTokens.bevelLight }
                Rectangle { y: root.hair; width: parent.width; height: root.hair; color: PlatinumTokens.bevelDark }
            }
        }
    }

    Box {
        id: closeBox
        objectName: "closeBox"
        x: 7
        visible: root.front && root.closable
        held: closeArea.pressed && closeArea.containsMouse
        Accessible.role: Accessible.Button
        Accessible.name: "Close"
        MouseArea { id: closeArea; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; onClicked: root.closeClicked() }
    }
    Box {
        id: collapseBox
        visible: root.front && root.collapsible
        anchors.right: parent.right
        anchors.rightMargin: 7
        held: collapseArea.pressed && collapseArea.containsMouse
        Accessible.role: Accessible.Button
        Accessible.name: "Collapse"
        Rectangle { x: 2; y: 5; width: parent.width - 4; height: root.hair; color: PlatinumTokens.menuEdge }
        Rectangle { x: 2; y: 7; width: parent.width - 4; height: root.hair; color: PlatinumTokens.menuEdge }
        MouseArea { id: collapseArea; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: root.collapseClicked() }
    }
    Box {
        id: zoomBox
        visible: root.front && root.zoomable
        anchors.right: collapseBox.left
        anchors.rightMargin: 5
        held: zoomArea.pressed && zoomArea.containsMouse
        Accessible.role: Accessible.Button
        Accessible.name: "Zoom"
        Rectangle { x: 2; y: 2; width: 6; height: 6; color: "transparent"; border.width: root.hair; border.color: PlatinumTokens.menuEdge }
        MouseArea { id: zoomArea; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: root.zoomClicked() }
    }

    readonly property real leftEdge: root.closable ? closeBox.x + closeBox.width + 5 : 6
    readonly property real rightEdge: (root.zoomable ? zoomBox.x : root.collapsible ? collapseBox.x : width) - 5
    readonly property real room: Math.max(0, rightEdge - leftEdge)

    Stripes { x: root.leftEdge; width: Math.max(0, label.x - 6 - x) }
    Text {
        id: label
        width: Math.min(implicitWidth, Math.max(0, root.room - 16))
        x: root.leftEdge + Math.max(8, (root.room - width) / 2)
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        color: root.front ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: 13
        font.letterSpacing: PlatinumTokens.platinumTracking
    }
    Stripes { x: label.x + label.width + 6; width: Math.max(0, root.rightEdge - x) }
}
