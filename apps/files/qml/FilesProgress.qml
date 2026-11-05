import QtQuick
import Hensou

// A progress bar in the current theme. value < 0 means the size is not
// known: Platinum draws its striped (barber pole) bar, still, and Memphis
// an empty bar; the caller's text says "unknown size".
Item {
    id: root
    property real value: 0
    readonly property bool win98: Theme.name === "win98"
    readonly property real u: 2 / WindowMetrics.ratio(root)
    implicitHeight: win98 ? 16 * u : 12
    implicitWidth: 120
    Accessible.role: Accessible.ProgressBar
    Accessible.name: value < 0 ? "Unknown progress" : Math.round(value * 100) + "%"

    Loader {
        anchors.fill: parent
        sourceComponent: root.win98 ? memphis : platinum
    }
    Component {
        id: platinum
        Item {
            readonly property real hair: PlatinumTokens.hairFor(WindowMetrics.ratio(root))
            Rectangle { anchors.fill: parent; color: PlatinumTokens.well; border.width: parent.hair; border.color: PlatinumTokens.menuEdge }
            Rectangle {
                visible: root.value >= 0
                x: parent.hair; y: parent.hair
                width: Math.max(0, (parent.width - 2 * parent.hair) * Math.max(0, Math.min(1, root.value)))
                height: parent.height - 2 * parent.hair
                color: PlatinumTokens.highlight
            }
            Item {
                visible: root.value < 0
                x: parent.hair; y: parent.hair
                width: parent.width - 2 * parent.hair
                height: parent.height - 2 * parent.hair
                clip: true
                Row {
                    spacing: 6
                    Repeater {
                        model: Math.ceil(root.width / 12) + 2
                        Rectangle { width: 6; height: 30; rotation: 35; y: -9; color: PlatinumTokens.highlight; antialiasing: true }
                    }
                }
            }
        }
    }
    Component {
        id: memphis
        Win98LevelBar {
            value: Math.max(0, root.value)
            blocks: true
        }
    }
}
