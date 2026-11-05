// PROTOTYPE — a big task replaces the work area: an opaque black screen inside the
// frame, with its own bracket (a thin bar with a pill end top and bottom, a
// heavier block down the left). The apps are still running behind it; nothing
// is dimmed or layered on top of them. Esc returns the work area.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    id: t
    property var screen
    readonly property var s: screen
    property string title: ""
    property string code: ""
    property color color: T.sunset
    property real sideW: 150
    default property alias content: body.data
    x: s.f.work.x - 4; y: s.f.work.y - 4; width: s.f.work.w + 8; height: s.f.work.h + 8
    Rectangle { anchors.fill: parent; color: T.space }
    Rectangle { x: t.sideW + 8; y: 8; width: t.width - t.sideW - 16; height: 8; color: t.color; topRightRadius: 4; bottomRightRadius: 4 }
    Rectangle { x: t.sideW + 8; y: t.height - 16; width: t.width - t.sideW - 16; height: 8; color: t.color; topRightRadius: 4; bottomRightRadius: 4 }
    Rectangle {
        x: 8; y: 8; width: t.sideW; height: t.height - 16; color: t.color
        topLeftRadius: 30; bottomLeftRadius: 30
        Text { anchors.right: parent.right; anchors.rightMargin: 12; y: 30; text: t.title.toUpperCase(); color: T.space; font.family: s.fam; font.pixelSize: 30 }
        Text { anchors.right: parent.right; anchors.rightMargin: 12; y: 70; text: t.code.toUpperCase(); color: T.space; font.family: s.fam; font.pixelSize: 15 }
        Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 24; text: "ESC RETURNS"; color: T.space; font.family: s.fam; font.pixelSize: 15 }
    }
    Item { id: body; x: t.sideW + 40; y: 40; width: t.width - t.sideW - 72; height: t.height - 80 }
}
