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
    function init() {
        Theme.name = "platinum";
        Theme.mode = "dark";
        Theme.extraState = "off";
        app = createTemporaryObject(appComponent, null);
        verify(app);
        app.requestActivate();
        wait(100);
    }
    function cleanup() { if (app) app.close(); }
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
            compare(control("editableInput").selectionStart, 0);
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
    function test_native_popup_and_modal_focus_return() {
        app.width = 220;
        app.height = 180;
        wait(30);
        const button = control("moreButton");
        button.takeFocus();
        keyClick(Qt.Key_Return);
        const menu = control("actionsMenu");
        tryCompare(menu, "opened", true);
        compare(menu.popupType, 1); // Popup.Window
        verify(menu.contentItem.Window.window !== app);
        verify(menu.contentItem.width > app.width);
        keyClick(Qt.Key_Escape);
        tryCompare(menu, "opened", false);
        wait(50);
        compare(button.item.activeFocus, true);
        app.width = 640; app.height = 480;
        wait(30);
        const dialogButton = control("dialogButton");
        dialogButton.takeFocus();
        keyClick(Qt.Key_Return);
        const dialog = control("modalDialog");
        tryCompare(dialog, "visible", true);
        compare(dialog.modality, Qt.WindowModal);
        const clicks = app.state.clicks;
        mouseClick(control("incrementButton").item);
        compare(app.state.clicks, clicks);
        control("closeDialog").takeFocus();
        keyClick(Qt.Key_Return);
        tryCompare(dialog, "visible", false);
        wait(50);
        compare(dialogButton.item.activeFocus, true);
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
