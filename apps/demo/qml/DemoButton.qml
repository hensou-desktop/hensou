import QtQuick
import Hensou

Loader {
    id: root
    property string text: ""
    property bool wantsFocus: false
    onLoaded: Qt.callLater(function() { if (root.wantsFocus) root.takeFocus(); })
    signal clicked()
    signal focused()
    sourceComponent: Theme.name === "win98" ? win98 : platinum
    function takeFocus() { if (item) item.forceActiveFocus(); }
    Component {
        id: platinum
        PlatinumButton {
            text: root.text
            Accessible.name: root.text
            onClicked: root.clicked()
            onActiveFocusChanged: if (activeFocus) root.focused()
        }
    }
    Component {
        id: win98
        Win98Button {
            text: root.text
            Accessible.name: root.text
            onClicked: root.clicked()
            onActiveFocusChanged: if (activeFocus) root.focused()
        }
    }
}
