import QtQuick
import Hensou

Loader {
    id: root
    property string text: "Keep this choice"
    property bool checked: false
    property bool wantsFocus: false
    onLoaded: Qt.callLater(function() { if (root.wantsFocus) root.takeFocus(); })
    signal changed(bool value)
    signal focused()
    sourceComponent: Theme.name === "memphis" ? memphis : platinum
    function takeFocus() { if (item) item.forceActiveFocus(); }
    Component {
        id: platinum
        PlatinumCheckBox {
            interactive: true
            text: root.text
            checked: root.checked
            Accessible.name: root.text
            onToggled: function(value) { root.changed(value); }
            onActiveFocusChanged: if (activeFocus) root.focused()
        }
    }
    Component {
        id: memphis
        MemphisCheckBox {
            text: root.text
            checked: root.checked
            Accessible.name: root.text
            onToggled: function(value) { root.changed(value); }
            onActiveFocusChanged: if (activeFocus) root.focused()
        }
    }
}
