import QtQuick
import Hensou

// A check box in the current theme. The owner keeps the state: toggled
// reports the next value.
Loader {
    id: root
    property string text: ""
    property bool checked: false
    signal toggled(bool checked)
    sourceComponent: Theme.name === "win98" ? memphis : platinum
    function takeFocus() { if (item) item.forceActiveFocus(); }
    Component {
        id: platinum
        PlatinumCheckBox {
            text: root.text
            checked: root.checked
            interactive: root.enabled
            enabled: root.enabled
            Accessible.name: root.text
            onToggled: function(next) { root.toggled(next); }
        }
    }
    Component {
        id: memphis
        Win98CheckBox {
            text: root.text
            checked: root.checked
            enabled: root.enabled
            Accessible.name: root.text
            onToggled: function(next) { root.toggled(next); }
        }
    }
}
