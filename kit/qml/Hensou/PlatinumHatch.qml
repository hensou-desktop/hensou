import QtQuick

// Drawing Board's shadow: graphite hatching, lines rising to the right one
// hair wide every three hairs, with a hair outline on the far edges. It is
// an SVG drawn at one source pixel per physical pixel, in hairs, so the
// hatch stays crisp at fractional scales. A frame puts it behind itself,
// offset down and right; the frame covers all but the two strips.
Image {
    id: root

    property color color: PlatinumTokens.menuShadow
    readonly property real ratio: PlatinumTokens.ratioFor(WindowMetrics.ratio(root))
    readonly property real hair: PlatinumTokens.hairFor(ratio)
    // Physical pixels per hair: 2 at 1.5, 1 at 1, 2 at 2.
    readonly property int px: Math.max(1, Math.round(hair * ratio))
    readonly property int cols: Math.max(1, Math.round(width / hair))
    readonly property int rows: Math.max(1, Math.round(height / hair))
    readonly property string svg: '<svg xmlns="http://www.w3.org/2000/svg" width="' + cols + '" height="' + rows
        + '" viewBox="0 0 ' + cols + ' ' + rows + '" shape-rendering="crispEdges">'
        + '<defs><pattern id="h" width="3" height="3" patternUnits="userSpaceOnUse">'
        + '<rect x="2" y="0" width="1" height="1" fill="' + color + '"/>'
        + '<rect x="1" y="1" width="1" height="1" fill="' + color + '"/>'
        + '<rect x="0" y="2" width="1" height="1" fill="' + color + '"/>'
        + '</pattern></defs><rect width="' + cols + '" height="' + rows + '" fill="url(#h)"/>'
        + '<rect x="' + (cols - 1) + '" y="0" width="1" height="' + rows + '" fill="' + color + '"/>'
        + '<rect x="0" y="' + (rows - 1) + '" width="' + cols + '" height="1" fill="' + color + '"/>'
        + '</svg>'

    smooth: false
    mipmap: false
    cache: false
    asynchronous: false
    sourceSize.width: cols * px
    sourceSize.height: rows * px
    source: width <= 0 || height <= 0 ? "" : "data:image/svg+xml;utf8," + encodeURIComponent(svg)
}
