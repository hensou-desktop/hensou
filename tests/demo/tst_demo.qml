import QtQuick
import QtTest
import Hensou
import Hensou.Host
import Hensou.Demo

TestCase {
    id: test
    name: "StandaloneDemo"
    when: windowShown
    width: 32
    height: 32
    property var app: null
    Component { id: appComponent; DemoWindow {} }
    Component { id: guardComponent; ModalInputGuard {} }
    function init() {
        Theme.name = "platinum";
        Theme.mode = "dark";
        Theme.extraState = "off";
        app = createTemporaryObject(appComponent, null);
        verify(app);
        verify(app.popupOverlay);
        app.activeChanged.connect(function() { console.log("OWNER_ACTIVE", app.active, "application", Qt.application.state, "harness", test.Window.window.active); });
        app.requestActivate();
        console.log("HENSOU_PHASE prime-input");
        wait(100);
    }
    function cleanup() {
        console.log("OWNER_FINAL_ACTIVE", app.active, "application", Qt.application.state, "harness", test.Window.window.active);
        console.log("HENSOU_PHASE fixture-state");
        wait(100);
        if (app) app.close();
    }
    function control(name) { return findChild(app, name); }
    function test_button_checkbox_disabled_and_keyboard_data() {
        return [{ tag: "platinum", name: "platinum" }, { tag: "win98", name: "win98" }];
    }
    function test_button_checkbox_disabled_and_keyboard(data) {
        Theme.name = data.name;
        wait(30);
        const button = control("incrementButton");
        compare(button.item.Accessible.role, Accessible.Button);
        compare(button.item.Accessible.name, "Increment");
        button.takeFocus();
        keyClick(Qt.Key_Return);
        compare(app.state.clicks, 1);
        const checkbox = control("checkboxControl");
        compare(checkbox.item.Accessible.role, Accessible.CheckBox);
        compare(checkbox.item.Accessible.name, "Keep this choice");
        checkbox.takeFocus();
        keyClick(Qt.Key_Space);
        compare(app.state.checked, true);
        app.state.editable = false;
        checkbox.takeFocus();
        keyClick(Qt.Key_Space);
        compare(app.state.checked, true);
        compare(control("fieldControl").enabled, false);
    }
    function test_live_switch_preserves_input_selection_checkbox_and_list() {
        const field = control("fieldControl");
        field.takeFocus();
        const input = control("editableInput");
        input.selectAll();
        keyClick(Qt.Key_H);
        keyClick(Qt.Key_I);
        input.select(0, 1);
        app.state.checked = true;
        app.state.selectedIndex = 7;
        for (const appearance of [["platinum", "light", "off"], ["platinum", "dark", "off"], ["platinum", "dark", "on"], ["win98", "light", "off"], ["win98", "dark", "on"]]) {
            Theme.name = appearance[0]; Theme.mode = appearance[1]; Theme.extraState = appearance[2];
            wait(80);
            compare(app.state.text, "hi");
            compare(control("editableInput").text, "hi");
            compare(control("editableInput").selectionStart, 0, "selection in " + appearance[0] + " owner=" + app.state.selectionStart + ":" + app.state.selectionEnd);
            compare(control("editableInput").selectionEnd, 1);
            compare(app.state.checked, true);
            compare(app.state.selectedIndex, 7);
            compare(control("fixtureList").currentIndex, 7);
        }
    }
    function test_empty_one_many_and_keyboard_reveals_selection() {
        for (const name of ["platinum", "win98"]) {
            Theme.name = name;
            wait(30);
            for (const count of [0, 1, 100]) {
                app.fixture(count);
                wait(30);
                compare(control("fixtureList").count, count);
                compare(app.state.selectedIndex, count ? 0 : -1);
                control("listControl").takeFocus();
                keyClick(Qt.Key_End);
                wait(30);
                if (count) compare(app.state.selectedIndex, count - 1);
                if (count > 1) verify(control("fixtureList").view.contentY > 0);
            }
        }
    }
    function test_guard_scope_and_detach() {
        const guard = createTemporaryObject(guardComponent, app, { ownerWindow: app, active: true });
        const increment = control("incrementButton");
        mouseClick(increment.item);
        compare(app.state.clicks, 0);
        app.showControlsWindow();
        wait(80);
        mouseClick(findChild(app.companion, "incrementButton").item);
        compare(app.state.clicks, 1);
        guard.ownerWindow = null;
        mouseClick(increment.item);
        compare(app.state.clicks, 2);
        guard.ownerWindow = app;
        guard.active = false;
        mouseClick(increment.item);
        compare(app.state.clicks, 3);
    }
    function test_native_popup_and_modal_focus_return() {
        console.log("HENSOU_PHASE resize-small-parent");
        wait(150);
        tryCompare(app, "width", 220);
        tryCompare(app, "height", 180);
        const button = control("moreButton");
        tryCompare(app, "active", true);
        button.takeFocus();
        tryCompare(button.item, "activeFocus", true);
        button.clicked.connect(function() { console.log("HENSOU_MORE_CLICKED"); });
        button.item.Keys.pressed.connect(function(event) { console.log("HENSOU_MORE_KEY", event.key, event.text, event.modifiers); });
        console.log("HENSOU_PRE_MENU_KEY", app.active, app.activeFocusItem, button.item.activeFocus);
        console.log("HENSOU_PHASE open-native-menu");
        const menu = control("actionsMenu");
        tryCompare(menu, "opened", true);
        compare(menu.popupType, 1); // Popup.Window
        tryVerify(function() { return menu.contentItem.Window.window && menu.contentItem.Window.window.visible && menu.contentItem.Window.window !== app; });
        wait(150);
        console.log("NATIVE_MENU_GEOMETRY", app.width, app.height, menu.contentItem.width, menu.contentItem.Window.window.width);
        verify(menu.contentItem.width > app.width);
        console.log("HENSOU_PHASE capture-menu-escape");
        wait(100);
        console.log("HENSOU_PHASE close-native-menu");
        tryCompare(menu, "opened", false);
        wait(50);
        compare(button.item.activeFocus, true);
        console.log("HENSOU_PHASE resize-large-parent");
        wait(150);
        tryCompare(app, "width", 640); tryCompare(app, "height", 480);
        const increment = control("incrementButton");
        const point = increment.mapToItem(app.contentItem, increment.width / 2, increment.height / 2);
        const before = app.state.clicks;
        console.log("HENSOU_PHASE parent-click-" + Math.round(point.x) + "-" + Math.round(point.y));
        tryCompare(app.state, "clicks", before + 1);
        const dialogButton = control("dialogButton");
        verify(dialogButton.visible);
        dialogButton.takeFocus();
        compare(dialogButton.item.activeFocus, true);
        console.log("HENSOU_PHASE open-native-dialog");
        const dialog = control("modalDialog");
        tryCompare(dialog, "visible", true);
        compare(dialog.popupType, 1);
        compare(dialog.modal, true);
        verify(dialog.contentItem.Window.window !== app);
        console.log("HENSOU_PHASE capture-modal");
        wait(100);
        const clicks = app.state.clicks;
        verify(point.x < dialog.requestedX || point.x > dialog.requestedX + dialog.width || point.y < dialog.requestedY || point.y > dialog.requestedY + dialog.height,
               "The blocked-parent target must not be covered by the dialog");
        console.log("HENSOU_PHASE block-parent-" + Math.round(point.x) + "-" + Math.round(point.y));
        wait(150);
        compare(app.state.clicks, clicks);
        compare(dialog.visible, true);
        console.log("DIALOG_KEYBOARD_STATE", dialog.activeFocus, dialog.contentItem.Window.window.active);
        console.log("HENSOU_PHASE close-native-dialog");
        tryCompare(dialog, "visible", false);
        console.log("DIALOG_RETURN_FOCUS", app.active, app.state.focusTarget, app.activeFocusItem, dialogButton.visible);
        tryCompare(dialogButton.item, "activeFocus", true);
    }
    function test_long_dialog_document_data() {
        return [{ tag: "platinum", name: "platinum" }, { tag: "win98", name: "win98" }];
    }
    function test_long_dialog_document(data) {
        Theme.name = data.name;
        const dialog = control("modalDialog");
        dialog.width = 220; dialog.height = 160;
        const label = "UnbrokenABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".repeat(6);
        dialog.openFrom("dialog", label);
        tryCompare(dialog, "visible", true);
        wait(50);
        const document = control("dialogDocument");
        verify(document.contentHeight > document.height);
        const message = control("dialogMessage");
        compare(message.text, label);
        verify(message.width <= document.width);
        document.forceActiveFocus();
        keyClick(Qt.Key_End);
        verify(document.contentY > 0);
        control("closeDialog").takeFocus();
        keyClick(Qt.Key_Return);
        tryCompare(dialog, "visible", false);
    }
    function test_menu_accessible_actions_data() {
        return [{ tag: "platinum", name: "platinum" }, { tag: "win98", name: "win98" }];
    }
    function test_menu_accessible_actions(data) {
        Theme.name = data.name;
        wait(30);
        const menu = control("actionsMenu");
        menu.openAt(control("moreButton"));
        tryCompare(menu, "opened", true);
        const index = menu.entries.findIndex(entry => entry.action === "empty");
        const action = findChild(menu.contentItem, "menuAction" + index);
        verify(action);
        compare(action.Accessible.role, Accessible.MenuItem);
        compare(action.Accessible.name, "Empty fixture");
        const disabled = findChild(menu.contentItem, "menuAction" + (menu.entries.length - 1));
        verify(disabled);
        compare(disabled.enabled, false);
        disabled.Accessible.pressAction();
        compare(app.state.rows.length, 20);
        action.Accessible.pressAction();
        tryCompare(menu, "opened", false);
        compare(app.state.rows.length, 0);
    }
    function test_awkward_shapes_keep_capabilities_reachable() {
        for (const size of [[220, 640], [1000, 180], [180, 100]]) {
            app.width = size[0]; app.height = size[1];
            wait(30);
            const more = control("moreButton");
            verify(more.visible);
            verify(more.x >= 0 && more.y >= 0);
            verify(more.mapToItem(app.contentItem, more.width, more.height).y <= app.height);
            if (size[1] >= 156) {
                verify(control("fieldControl").visible);
                verify(control("listControl").height > 0);
            } else {
                app.showControlsWindow();
                verify(app.companion.visible);
                compare(app.companion.state, app.state);
            }
        }
    }
}
