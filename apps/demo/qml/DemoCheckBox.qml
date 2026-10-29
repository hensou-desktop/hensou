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
    implicitWidth: item ? item.implicitWidth : 0
    implicitHeight: item ? item.implicitHeight : 0
    sourceComponent: Theme.name === "win98" ? win98 : platinum
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
        id: win98
        Win98CheckBox {
            text: root.text
            checked: root.checked
            Accessible.name: root.text
            onToggled: function(value) { root.changed(value); }
            onActiveFocusChanged: if (activeFocus) root.focused()
        }
    }
}
