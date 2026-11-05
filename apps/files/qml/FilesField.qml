import QtQuick
import Hensou

// A one-line edit field in the current theme.
Loader {
    id: root
    property string text: ""
    property string accessibleName: ""
    signal edited(string text)
    signal accepted()
    signal escaped()
    sourceComponent: Theme.name === "memphis" ? memphis : platinum
    function takeFocus() { if (item) { item.forceActiveFocus(); item.input.forceActiveFocus(); } }
    function selectAll() { if (item) item.input.selectAll(); }
    function selectBase() {
        // Select the name without its extension, as both Finders do.
        if (!item) return;
        const dot = root.text.lastIndexOf(".");
        item.input.select(0, dot > 0 ? dot : root.text.length);
    }
    readonly property string currentText: item ? item.text : root.text
    onTextChanged: if (item && item.text !== text) item.text = text
    function keys(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.accepted(); event.accepted = true; }
        else if (event.key === Qt.Key_Escape) { root.escaped(); event.accepted = true; }
    }
    Component {
        id: platinum
        PlatinumTextField {
            text: root.text
            enabled: root.enabled
            Accessible.name: root.accessibleName
            onEdited: function(value) { root.edited(value); }
            onKeyPressed: function(event) { root.keys(event); }
        }
    }
    Component {
        id: memphis
        MemphisTextField {
            text: root.text
            enabled: root.enabled
            Accessible.name: root.accessibleName
            onEdited: function(value) { root.edited(value); }
            onKeyPressed: function(event) { root.keys(event); }
        }
    }
}
