import QtQuick
import Hensou

Loader {
    id: root
    required property QtObject modelState
    property bool restoring: true
    signal focused()
    sourceComponent: Theme.name === "win98" ? win98 : platinum
    onSourceComponentChanged: restoring = true
    onLoaded: Qt.callLater(restore)
    function takeFocus() { if (item) item.input.forceActiveFocus(); }
    function restore() {
        if (!item) return;
        if (modelState.focusTarget === "field") takeFocus();
        item.input.cursorPosition = modelState.cursor;
        item.input.select(modelState.selectionStart, modelState.selectionEnd);
        restoring = false;
    }
    Connections {
        target: root.item ? root.item.input : null
        function onTextEdited() { if (!root.restoring) root.modelState.text = target.text; }
        function onCursorPositionChanged() { if (!root.restoring) root.modelState.cursor = target.cursorPosition; }
        function onSelectionStartChanged() { if (!root.restoring) root.modelState.selectionStart = target.selectionStart; }
        function onSelectionEndChanged() { if (!root.restoring) root.modelState.selectionEnd = target.selectionEnd; }
        function onActiveFocusChanged() { if (target.activeFocus) root.focused(); }
    }
    Component {
        id: platinum
        PlatinumTextField {
            Component.onDestruction: root.restoring = true
            text: root.modelState.text
            input.objectName: "editableInput"
            input.Accessible.name: "Editable text"
        }
    }
    Component {
        id: win98
        Win98TextField {
            Component.onDestruction: root.restoring = true
            text: root.modelState.text
            input.objectName: "editableInput"
            input.Accessible.name: "Editable text"
        }
    }
}
