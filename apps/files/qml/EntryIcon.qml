import QtQuick
import Hensou
import "Art.js" as Art

// One kind picture from the theme's own art: no thumbnails, no Adwaita.
// Memphis puts the shortcut arrow on aliases; Platinum marks aliases with
// an italic name instead (the caller's text). A cut or offline item dims.
Item {
    id: root
    property string art: "document"
    property bool large: true
    property bool alias: false
    property bool selected: false
    property bool dim: false
    readonly property bool win98: Theme.name === "win98"
    readonly property real ratio: WindowMetrics.ratio(root)
    readonly property real u: 2 / ratio
    // Memphis: 32 u large, 16 u small (one art pixel per physical pixel at
    // 16 u). Platinum: 32 and 16 logical px.
    readonly property real side: win98 ? (large ? 32 : 16) * u : (large ? 32 : 16)
    implicitWidth: side
    implicitHeight: side
    opacity: dim ? 0.45 : 1

    Image {
        anchors.fill: parent
        smooth: !root.win98
        mipmap: false
        sourceSize.width: Math.max(1, Math.round(root.side * root.ratio))
        sourceSize.height: Math.max(1, Math.round(root.side * root.ratio))
        source: Art.url(root.win98 ? "win98" : "platinum", root.art,
            root.win98 ? Win98Tokens.ink : "#000000",
            root.selected ? (root.win98 ? Win98Tokens.selection : "#000000") : "")
    }
    Image {
        visible: root.win98 && root.alias
        x: 0
        y: parent.height - height
        width: (root.large ? 11 : 7) * root.u
        height: width
        smooth: false
        sourceSize.width: Math.max(1, Math.round(width * root.ratio))
        sourceSize.height: Math.max(1, Math.round(height * root.ratio))
        source: visible ? Art.url("win98", "shortcut", Win98Tokens.ink, "") : ""
    }
}
