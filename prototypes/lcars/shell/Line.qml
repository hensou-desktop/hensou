// PROTOTYPE — one menu row: a small colour block, the label on the text edge,
// the value on the right edge. Selected rows light gold.
import QtQuick
import "../tokens.js" as T

Item {
    id: l
    property string label: ""
    property string value: ""
    property string tag: ""             // tiny code in the block, e.g. "5G"
    property color color: T.lilac
    property color valueColor: T.periwinkle
    property bool selected: false
    property bool check: false
    property string fam: ""
    property real px: 22
    width: parent ? parent.width : 300
    height: px + 16
    Rectangle {
        width: 46; height: l.height - 4; y: 2; color: l.color
        topLeftRadius: height / 2; bottomLeftRadius: height / 2
        Text { anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; text: l.tag.toUpperCase(); color: T.space; font.family: l.fam; font.pixelSize: 12 }
    }
    Rectangle {
        x: 50; y: 2; width: parent.width - 50; height: l.height - 4
        color: l.selected ? T.gold : "transparent"
        Text {
            x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 130; elide: Text.ElideRight
            text: (l.check ? "● " : "") + l.label; color: l.selected ? T.space : T.peach; font.family: l.fam; font.pixelSize: l.px
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            text: l.value; color: l.selected ? T.space : l.valueColor; font.family: l.fam; font.pixelSize: l.px - 3
        }
    }
}
