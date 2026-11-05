// PROTOTYPE — an LCARS level: a run of blocks, lit up to the value.
import QtQuick
import "../tokens.js" as T

Row {
    id: lb
    property real value: 0.5          // 0..1
    property int blocks: 20
    property color color: T.sunset
    property real blockH: 18
    property real blockW: 10
    spacing: 3
    Repeater {
        model: lb.blocks
        delegate: Rectangle {
            required property int index
            width: lb.blockW; height: lb.blockH
            color: (index + 0.5) / lb.blocks <= lb.value ? lb.color : T.dim
        }
    }
}
