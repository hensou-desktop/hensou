import QtQuick
import Hensou

// A push button in the current theme. Buttons of one role share a width:
// pass every label of the role in roleLabels.
Loader {
    id: root
    property string text: ""
    property bool isDefault: false
    property var roleLabels: []
    signal clicked()
    readonly property bool win98: Theme.name === "win98"
    sourceComponent: win98 ? memphis : platinum
    activeFocusOnTab: false
    function takeFocus() { if (item) item.forceActiveFocus(); }
    Accessible.role: Accessible.Button
    Accessible.name: text
    Component {
        id: platinum
        PlatinumButton {
            text: root.text
            isDefault: root.isDefault
            enabled: root.enabled
            fixedWidth: root.roleLabels.length > 0 ? PlatinumMetrics.buttonWidth(root.roleLabels) : 0
            Accessible.name: root.text
            onClicked: root.clicked()
        }
    }
    Component {
        id: memphis
        Win98Button {
            text: root.text
            isDefault: root.isDefault
            enabled: root.enabled
            roleLabels: root.roleLabels
            Accessible.name: root.text
            onClicked: root.clicked()
        }
    }
}
