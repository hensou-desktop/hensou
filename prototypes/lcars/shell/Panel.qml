// PROTOTYPE — a control's menu as a sub-frame that grows down out of its bar
// segment: the segment's colour runs down the left as a spine and turns along
// the bottom through a small elbow. Black body, LCARS rows inside.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    id: p
    property color color: T.sunset
    property string title: ""
    property string code: ""              // the key that opens it, e.g. "Super+O S"
    property string fam: ""
    property real spine: 22
    default property alias content: body.data
    readonly property real bodyX: spine + 18
    readonly property real bodyW: width - bodyX - 14

    Rectangle { anchors.fill: parent; color: T.space }
    // Spine and bottom elbow.
    Elbow { corner: "bl"; armW: p.spine; barH: 14; y: p.height - 56; width: p.spine + 40; height: 56; color: p.color }
    Rectangle { width: p.spine; height: p.height - 56; color: p.color }
    Rectangle {
        x: p.spine + 44; y: p.height - 14; width: p.width - p.spine - 44; height: 14; color: p.color
        topRightRadius: 7; bottomRightRadius: 7
        Text { visible: p.code !== ""; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: p.code.toUpperCase(); color: T.space; font.family: p.fam; font.pixelSize: 12 }
    }
    Text { x: p.bodyX; y: 6; text: p.title; color: p.color; font.family: p.fam; font.pixelSize: 30; font.weight: Font.Medium }
    Item { id: body; x: p.bodyX; y: 48; width: p.bodyW; height: p.height - 48 - 24 }
}
