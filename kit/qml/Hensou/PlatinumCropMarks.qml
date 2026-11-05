import QtQuick

// Drawing Board's frame: a graphite hair over each edge of its parent,
// running PlatinumTokens.frameOverrun past both corners like the crop
// marks on a drafting sheet. Put it last, so it lies over the frame's own
// edge. It takes no input.
Item {
    id: root

    property color color: PlatinumTokens.frameLine
    property real overrun: PlatinumTokens.frameOverrun
    readonly property real hair: PlatinumTokens.hairFor(WindowMetrics.ratio(root))
    readonly property real run: Math.round(overrun / hair) * hair

    anchors.fill: parent

    Rectangle { x: -root.run; y: 0; width: root.width + 2 * root.run; height: root.hair; color: root.color }
    Rectangle { x: -root.run; y: root.height - root.hair; width: root.width + 2 * root.run; height: root.hair; color: root.color }
    Rectangle { x: 0; y: -root.run; width: root.hair; height: root.height + 2 * root.run; color: root.color }
    Rectangle { x: root.width - root.hair; y: -root.run; width: root.hair; height: root.height + 2 * root.run; color: root.color }
}
