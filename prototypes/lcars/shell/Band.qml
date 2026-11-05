// PROTOTYPE — a quick control opens as a band under the top bar: the TNG split
// screen. A seam bar closes it off from the work area below, and Hyprland
// moves the tiled windows down (a layer-shell exclusive zone), so nothing
// overlaps. The band's title block carries the segment's colour.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    id: b
    property var screen
    readonly property var s: screen
    property string title: ""
    property string code: ""
    property color color: T.gold
    default property alias content: body.data
    x: s.f.armW + 14; y: s.f.topH + 10
    width: s.width - x - 10; height: s.bandH - 24
    // Title block on the left, label at its foot like a sidebar block.
    Rectangle {
        width: 170; height: b.height; color: b.color
        topLeftRadius: 0; bottomLeftRadius: 24
        Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; text: b.title.toUpperCase(); color: T.space; font.family: s.fam; font.pixelSize: 30 }
        Text { anchors.right: parent.right; anchors.rightMargin: 12; y: 8; text: b.code.toUpperCase(); color: T.space; font.family: s.fam; font.pixelSize: 15 }
    }
    Item { id: body; x: 194; y: 4; width: b.width - 194; height: b.height - 8 }
}
