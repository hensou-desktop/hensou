import QtQuick
import Hensou

Loader {
    id: root
    required property QtObject state
    property bool restoring: true
    signal focused()
    implicitWidth: item ? item.implicitWidth : 0
    implicitHeight: item ? item.implicitHeight : 0
    sourceComponent: Theme.name === "win98" ? win98 : platinum
    onSourceComponentChanged: restoring = true
    onLoaded: Qt.callLater(restore)
    function takeFocus() { if (item) item.input.forceActiveFocus(); }
    function restore() {
        if (!item) return;
        item.input.cursorPosition = state.cursor;
        item.input.select(state.selectionStart, state.selectionEnd);
        if (state.focusTarget === "field") takeFocus();
        restoring = false;
    }
    Connections {
        target: root.item ? root.item.input : null
        function onTextEdited() { if (!root.restoring) root.state.text = target.text; }
        function onCursorPositionChanged() { if (!root.restoring) root.state.cursor = target.cursorPosition; }
        function onSelectionStartChanged() { if (!root.restoring) root.state.selectionStart = target.selectionStart; }
        function onSelectionEndChanged() { if (!root.restoring) root.state.selectionEnd = target.selectionEnd; }
        function onActiveFocusChanged() { if (target.activeFocus) root.focused(); }
    }
    Component {
        id: platinum
        PlatinumTextField {
            text: root.state.text
            input.objectName: "editableInput"
            input.Accessible.name: "Editable text"
        }
    }
    Component {
        id: win98
        Win98TextField {
            text: root.state.text
            input.objectName: "editableInput"
            input.Accessible.name: "Editable text"
        }
    }
}
