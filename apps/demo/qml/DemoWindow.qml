import QtQuick
import QtQuick.Layouts
import Hensou
import Hensou.Host
import "LayoutPlan.js" as LayoutPlan

Window {
    id: root
    property QtObject state: QtObject {
        property string text: "Type here"
        property int cursor: 0
        property int selectionStart: 0
        property int selectionEnd: 0
        property bool checked: false
        property bool editable: true
        property int clicks: 0
        property int selectedIndex: 0
        property string focusTarget: "field"
        property var rows: ["One row", "A long fixture label: every character remains available in the dialog", "UnbrokenLabelABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", "Fourth row", "Fifth row", "Sixth row", "Seventh row", "Eighth row", "Ninth row", "Tenth row", "Eleventh row", "Twelfth row", "Thirteenth row", "Fourteenth row", "Fifteenth row", "Sixteenth row", "Seventeenth row", "Eighteenth row", "Nineteenth row", "Twentieth row"]
    }
    property var companion: null
    readonly property var layoutPlan: LayoutPlan.plan(width, height)
    readonly property real actualDpr: metrics.devicePixelRatio
    title: "Hensou demo"
    width: 640
    height: 480
    minimumWidth: 180
    minimumHeight: 100
    visible: true
    color: Theme.name === "win98" ? Win98Tokens.face : PlatinumTokens.menuSurface
    function restoreFocus(target) {
        if (dialog.visible) return;
        state.focusTarget = target;
        const control = { field: field, checkbox: checkbox, list: rows, increment: increment, menu: more, dialog: dialogButton }[target];
        if (control && control.visible && control.enabled) control.takeFocus();
        else more.takeFocus();
    }
    function showControlsWindow() {
        if (!companion) companion = windowComponent.createObject(null, { state: root.state });
        companion.show();
        companion.requestActivate();
    }
    function fixture(count) {
        state.rows = Array.from({ length: count }, function(_, index) {
            return index === 0 ? "A long fixture label with spaces and all of its text reachable by Enter" : index === 1 ? "UnbrokenLabelABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" : "Fixture row " + (index + 1);
        });
        state.selectedIndex = count ? 0 : -1;
    }
    function action(name) {
        if (name === "empty") fixture(0);
        else if (name === "one") fixture(1);
        else if (name === "many") fixture(100);
        else if (name === "enabled") state.editable = !state.editable;
        else if (name === "dialog") dialog.openFrom("menu", "This is a modal dialog. The parent cannot receive input until you close it.");
        else if (name === "second") showControlsWindow();
    }
    Component { id: windowComponent; DemoWindow { title: "Hensou controls window" } }
    onClosing: {
        if (companion) companion.destroy();
        companion = null;
    }
    WindowScale {
        id: scale
        anchors.fill: parent
        devicePixelRatio: metrics.devicePixelRatio
        NativeWindowMetrics { id: metrics }
        ColumnLayout {
            id: frame
            anchors.fill: parent
            anchors.margins: root.layoutPlan.gap
            spacing: root.layoutPlan.gap
            RowLayout {
                Layout.fillWidth: true
                spacing: root.layoutPlan.gap
                DemoButton {
                    id: increment
                    objectName: "incrementButton"
                    text: "Increment"
                    onClicked: root.state.clicks++
                    onFocused: root.state.focusTarget = "increment"
                }
                DemoButton {
                    id: more
                    objectName: "moreButton"
                    text: "More"
                    onClicked: menu.openAt(more)
                    onFocused: root.state.focusTarget = "menu"
                }
                DemoButton {
                    id: dialogButton
                    objectName: "dialogButton"
                    text: "Dialog"
                    visible: frame.width > 370
                    onClicked: dialog.openFrom("dialog", "This is a modal dialog. The parent cannot receive input until you close it.")
                    onFocused: root.state.focusTarget = "dialog"
                }
                DemoLabel {
                    text: "Count: " + root.state.clicks
                    visible: frame.width > 480
                    Layout.fillWidth: true
                }
            }
            GridLayout {
                id: details
                visible: root.layoutPlan.structure !== "overflow"
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: root.layoutPlan.structure === "split" ? 2 : 1
                columnSpacing: root.layoutPlan.gap
                rowSpacing: root.layoutPlan.gap
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.layoutPlan.structure === "split" ? details.width / 2 : Infinity
                    spacing: root.layoutPlan.gap
                    DemoField {
                        id: field
                        objectName: "fieldControl"
                        modelState: root.state
                        enabled: root.state.editable
                        Layout.fillWidth: true
                        onFocused: root.state.focusTarget = "field"
                    }
                    DemoCheckBox {
                        id: checkbox
                        objectName: "checkboxControl"
                        checked: root.state.checked
                        enabled: root.state.editable
                        Layout.fillWidth: true
                        onChanged: function(value) { root.state.checked = value; }
                        onFocused: root.state.focusTarget = "checkbox"
                    }
                    DemoButton {
                        text: "Unavailable"
                        enabled: false
                        visible: root.height >= 300
                    }
                }
                DemoList {
                    id: rows
                    objectName: "listControl"
                    modelState: root.state
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    onFocused: root.state.focusTarget = "list"
                    onActivated: function(index) {
                        if (index >= 0) dialog.openFrom("list", root.state.rows[index]);
                    }
                }
            }
            Item { visible: !details.visible; Layout.fillHeight: true }
        }
    }
    DemoMenu {
        id: menu
        objectName: "actionsMenu"
        owner: root
        entries: [
            { text: "Open controls window", action: "second" },
            { text: "Open modal dialog", action: "dialog" },
            { text: "Empty fixture", action: "empty" },
            { text: "One-row fixture", action: "one" },
            { text: "Many rows and long labels", action: "many" },
            { text: root.state.editable ? "Disable input and checkbox" : "Enable input and checkbox", action: "enabled" },
            { text: "Count: " + root.state.clicks, enabled: false, action: "count" }
        ]
        onChosen: function(action) { root.action(action); }
    }
    DemoDialog { id: dialog; objectName: "modalDialog"; owner: root }
}
