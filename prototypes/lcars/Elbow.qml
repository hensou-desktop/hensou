// PROTOTYPE — LCARS elbow: a vertical arm (armW) joined to a horizontal bar (barH)
// with a large outer curve and a small inner curve. corner: "tl" or "bl".
import QtQuick
import "tokens.js" as T

Item {
    id: e
    property string corner: "tl"
    property real armW: 160
    property real barH: 56
    property color color: T.sunset
    property real outerR: Math.min(armW, height) * 0.75
    property real innerR: Math.min(barH, armW) * 0.6
    property string label: ""
    property string fam: ""

    Rectangle {
        anchors.fill: parent
        color: e.color
        topLeftRadius: e.corner === "tl" ? e.outerR : 0
        bottomLeftRadius: e.corner === "bl" ? e.outerR : 0
    }
    Rectangle {
        // The black notch that makes the inner curve.
        x: e.armW
        y: e.corner === "tl" ? e.barH : 0
        width: e.width - e.armW + 1
        height: e.height - e.barH + (e.corner === "tl" ? 1 : 0)
        color: T.space
        topLeftRadius: e.corner === "tl" ? e.innerR : 0
        bottomLeftRadius: e.corner === "bl" ? e.innerR : 0
    }
    Text {
        visible: e.label !== ""
        text: e.label.toUpperCase()
        font.family: e.fam
        font.pixelSize: 15
        color: T.space
        x: e.armW - width - 10
        y: e.corner === "tl" ? e.height - height - 4 : 4
    }
}
