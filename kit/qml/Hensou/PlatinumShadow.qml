import QtQuick

// The shadow under a Platinum menu, dialog or windoid. Light and Dark grey:
// a solid block `hairs` rules down and right. Drawing Board: graphite
// hatching four rules down and right (PlatinumHatch). Put it first in the
// frame, so the frame covers all but the shadow's two strips.
Item {
    id: root

    property int hairs: 1
    property real radius: 0
    readonly property real hair: PlatinumTokens.hairFor(WindowMetrics.ratio(root))
    readonly property bool hatched: PlatinumTokens.drafting

    x: (hatched ? 5 : hairs) * hair
    y: (hatched ? 5 : hairs) * hair
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    Rectangle {
        visible: !root.hatched
        anchors.fill: parent
        radius: root.radius
        color: PlatinumTokens.menuShadow
    }
    PlatinumHatch {
        visible: root.hatched
        width: visible ? root.width : 0
        height: visible ? root.height : 0
    }
}
