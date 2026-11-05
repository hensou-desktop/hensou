// PROTOTYPE — LCARS block / pill button. Label sits bottom-right, as on screen in TNG.
import QtQuick
import "tokens.js" as T

Rectangle {
    id: pill
    property string text: ""
    property string sub: ""          // small second label, top-left
    property bool leftCap: true
    property bool rightCap: true
    property string fam: ""
    property int px: Math.max(14, Math.round(height * 0.42))
    property color ink: T.space
    property bool active: false
    signal clicked()

    color: T.sunset
    implicitHeight: 44
    topLeftRadius: leftCap ? height / 2 : 0
    bottomLeftRadius: leftCap ? height / 2 : 0
    topRightRadius: rightCap ? height / 2 : 0
    bottomRightRadius: rightCap ? height / 2 : 0

    Rectangle {
        // Current-place marker: a small black lamp at the top right, not a glow.
        visible: pill.active
        width: 10; height: 10; radius: 5
        anchors.top: parent.top; anchors.topMargin: 5
        anchors.right: parent.right; anchors.rightMargin: pill.rightCap ? pill.height / 2 : 8
        color: T.space
    }
    Text {
        text: pill.text.toUpperCase()
        color: pill.ink
        font.family: pill.fam
        font.pixelSize: pill.px
        font.weight: Font.Medium
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: pill.rightCap ? pill.height / 2 : 10
        anchors.bottomMargin: 2
        width: Math.max(0, parent.width - (pill.leftCap ? pill.height / 2 : 8) - anchors.rightMargin - 8)
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }
    Text {
        visible: pill.sub !== "" && pill.height >= 40
        text: pill.sub.toUpperCase()
        color: pill.ink
        font.family: pill.fam
        font.pixelSize: Math.round(pill.px * 0.55)
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: pill.leftCap ? pill.height / 2 + 10 : 10
        anchors.topMargin: 3
    }
    MouseArea { anchors.fill: parent; onClicked: pill.clicked() }
}
