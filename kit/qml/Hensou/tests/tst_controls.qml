import QtQuick
import QtTest
import Hensou

TestCase {
    id: test
    name: "HensouControls"
    width: 800
    height: 600
    when: windowShown
    visible: true

    WindowScale {
        id: first
        width: 380; height: 600
        devicePixelRatio: 1.5
        Column {
            spacing: 12
            PlatinumButton { id: pbutton; text: "Change value"; onClicked: test.clicks++ }
            PlatinumTextField { id: pinput; Accessible.name: "Platinum draft" }
            PlatinumCheckBox { id: pcheck; text: "Keep draft"; interactive: true; onToggled: value => { test.nextChecked = value; test.toggleCount++; } }
            Win98Button { id: wbutton; text: "&Change value"; onClicked: test.clicks++ }
            Win98TextField { id: winput; Accessible.name: "Win98 draft" }
            Win98CheckBox { id: wcheck; text: "&Keep draft"; onToggled: value => { test.nextChecked = value; test.toggleCount++; } }
        }
    }
    WindowScale {
        id: second
        x: 400; width: 380; height: 600
        devicePixelRatio: 1
        Win98Bevel { id: otherBevel; width: 100; height: 100 }
    }
    property int clicks: 0
    property bool nextChecked: false
    property int toggleCount: 0

    function init() {
        clicks = 0; nextChecked = false; toggleCount = 0;
        first.devicePixelRatio = 1.5;
        second.devicePixelRatio = 1;
        pbutton.enabled = true; wbutton.enabled = true;
        Theme.name = "platinum"; Theme.mode = "dark"; Theme.extraState = "off";
    }
    function test_window_local_scale() {
        compare(wbutton.u * first.devicePixelRatio, 2);
        compare(otherBevel.u * second.devicePixelRatio, 2);
        second.devicePixelRatio = 2;
        compare(wbutton.u, 4 / 3);
        compare(otherBevel.u, 1);
        first.devicePixelRatio = 1;
        compare(wbutton.u, 2);
        compare(otherBevel.u, 1);
        compare(PlatinumTokens.hairFor(1.5) * 1.5, 2);
    }
    function test_button_keys_and_disabled() {
        for (const button of [pbutton, wbutton]) {
            button.forceActiveFocus();
            keyPress(Qt.Key_Space);
            verify(button.down, "Space draws the pressed state");
            keyRelease(Qt.Key_Space);
            keyClick(Qt.Key_Return);
            compare(clicks, 2);
            button.enabled = false;
            mouseClick(button);
            compare(clicks, 2);
            clicks = 0;
        }
    }
    function test_checkbox_next_value_is_not_owner_mutation() {
        for (const check of [pcheck, wcheck]) {
            check.checked = false;
            toggleCount = 0;
            check.forceActiveFocus();
            keyClick(Qt.Key_Space);
            verify(nextChecked);
            compare(toggleCount, 1);
            compare(check.checked, false);
            nextChecked = false;
            waitForRendering(check);
            mouseClick(check, check.width / 2, check.height / 2);
            verify(nextChecked, "pointer " + check + " " + check.width + "x" + check.height);
            compare(toggleCount, 2);
            compare(check.checked, false);
        }
    }
    function test_edit_and_theme_keeps_draft() {
        for (const input of [pinput, winput]) {
            input.text = "";
            input.input.forceActiveFocus();
            keyClick(Qt.Key_A); keyClick(Qt.Key_B);
            compare(input.text, "ab");
            Theme.name = "win98"; Theme.mode = "light"; Theme.extraState = "on";
            compare(input.text, "ab");
            compare(Win98Tokens.face.toString(), "#c0c0c0");
        }
    }
    function test_menu_accessible_actions_and_disabled_state() {
        const menu = Qt.createQmlObject('import QtQuick; import Hensou; Win98MenuPanel {}', first, "menu");
        menu.items = [{text: "&Open", shortcut: "Enter"}, {separator: true},
                      {text: "Unavailable", enabled: false}, {text: "Section", header: true}];
        menu.highlighted = 0;
        waitForRendering(menu);
        let activated = -1;
        menu.clicked.connect(index => { activated = index; });
        compare(menu.Accessible.role, Accessible.PopupMenu);
        const action = findChild(menu, "menuAction0");
        verify(action !== null);
        compare(action.Accessible.role, Accessible.MenuItem);
        compare(action.Accessible.name, "Open");
        compare(action.Accessible.selected, true);
        compare(action.enabled, true);
        action.Accessible.pressAction();
        compare(activated, 0);
        for (const index of [1, 2, 3]) {
            const item = findChild(menu, "menuAction" + index);
            verify(item !== null);
            compare(item.enabled, false);
            activated = -1;
            item.Accessible.pressAction();
            compare(activated, -1);
        }
        compare(findChild(menu, "menuAction1").Accessible.ignored, true);
        compare(findChild(menu, "menuAction3").Accessible.role, Accessible.StaticText);
        const row = Qt.createQmlObject('import QtQuick; import Hensou; PlatinumMenuListRow { name: "Open" }', first, "row");
        row.Accessible.role = Accessible.MenuItem;
        row.clicked.connect(() => { activated = 4; });
        row.Accessible.pressAction();
        compare(activated, 4);
        row.enabled = false;
        activated = -1;
        row.Accessible.pressAction();
        compare(activated, -1);
        menu.destroy(); row.destroy();
    }
    function test_long_and_mixed_content_renders() {
        // Generic controls have no async data owner: loading/error UI belongs
        // to their consuming view. Empty/missing text uses the empty string.
        const labels = ["", "A", "Built-in Speakers", "Galaxy Buds2 Pro", "U2723QE (HDMI 1)",
                        "UnbrokenLabel".repeat(30), "0", "-1", "999999999999999999999", "—"];
        for (const label of labels) {
            for (const type of ["PlatinumMenuListRow", "Win98ListRow"]) {
                const row = Qt.createQmlObject('import QtQuick; import Hensou; ' + type +
                    ' { width: 200; height: 40 }', first, type);
                if (type === "Win98ListRow") row.title = label;
                else row.name = label;
                waitForRendering(row);
                verify(isFinite(row.implicitWidth));
                verify(isFinite(row.implicitHeight));
                compare(row.Accessible.name, label);
                row.destroy();
            }
        }
    }
    function test_unbroken_wrap_mode_preserves_default() {
        const label = Qt.createQmlObject('import QtQuick; import Hensou; Win98Text { width: 110; wrap: true; accessMarks: false; elide: Text.ElideNone }', first, "wrappedLabel");
        label.text = "UnbrokenRawPath".repeat(30);
        compare(label.wrapMode, Text.WordWrap);
        label.wrapMode = Text.WrapAnywhere;
        waitForRendering(label);
        let face = null;
        for (const child of label.children[0].children) {
            if (child.visible && child.contentWidth !== undefined) { face = child; break; }
        }
        verify(face !== null);
        compare(face.wrapMode, Text.WrapAnywhere);
        verify(face.lineCount > 1);
        verify(face.contentWidth * label.k * label.size <= label.width,
               "wrapped raw text stays inside its requested width");
        compare(label.drawnText, label.text);
        verify(!label.truncated);
        label.destroy();
    }
    function test_platinum_extended_navigation_and_reveal() {
        for (const count of [0, 1, 100]) {
            const list = Qt.createQmlObject('import QtQuick; import Hensou; PlatinumMenuList { width: 200; height: 100; delegate: Item { width: 200; height: 20 } }', first, "navigationList");
            list.model = count;
            tryCompare(list, "count", count);
            list.view.forceActiveFocus();
            keyClick(Qt.Key_End);
            tryCompare(list, "currentIndex", count - 1);
            if (count > 0) {
                tryVerify(() => list.view.currentItem !== null);
                waitForRendering(list);
                verify(list.view.currentItem.y >= list.view.contentY);
                verify(list.view.currentItem.y + list.view.currentItem.height <= list.view.contentY + list.view.height);
                keyClick(Qt.Key_Home);
                compare(list.currentIndex, 0);
                keyClick(Qt.Key_PageDown);
                compare(list.currentIndex, Math.min(count - 1, 4));
                keyClick(Qt.Key_PageUp);
                compare(list.currentIndex, 0);
                list.extendedNavigationEnabled = false;
                keyClick(Qt.Key_End);
                compare(list.currentIndex, 0, "legacy shell does not gain a child End handler");
                list.enabled = false;
                keyClick(Qt.Key_PageDown);
                compare(list.currentIndex, 0);
            }
            list.destroy();
        }
    }
    function test_icon_resolver_missing_menu_and_app_fallback() {
        const requests = [];
        const fallback = PlatinumIconStore.url("folder", "#000000", "transparent");
        first.iconResolver = (name, checkOnly) => {
            requests.push({name: name, checkOnly: checkOnly});
            return checkOnly ? "" : fallback;
        };
        const menu = Qt.createQmlObject('import QtQuick; import Hensou; Win98MenuPanel {}', first, "missingIconMenu");
        menu.items = [{text: "Unknown app", themeIcon: "missing-application"}];
        waitForRendering(menu);
        const glyph = findChild(menu, "menuGlyph0");
        verify(glyph !== null);
        compare(glyph.name, "doc", "missing menu art keeps the built-in document glyph");
        const icon = Qt.createQmlObject('import QtQuick; import Hensou; Win98Icon { name: "theme:missing-application" }', first, "missingAppIcon");
        waitForRendering(icon);
        verify(requests.some(request => request.name === "missing-application" && request.checkOnly === true));
        verify(requests.some(request => request.name === "missing-application" && request.checkOnly === false));
        first.iconResolver = null;
        menu.destroy(); icon.destroy();
    }
    function test_resources_relocated() {
        verify(PlatinumIconStore.url("check", "#ffffff", "transparent").startsWith("data:image/svg+xml;utf8,"));
        verify(Win98IconStore.url("check", "#ffffff").startsWith("data:image/svg+xml;utf8,"));
        compare(Win98IconStore.size("check").length, 2);
    }
    function test_drawing_types_and_count_fixtures() {
        // Instantiate every exported drawing with plain Qt, never a shell.
        for (const type of ["PlatinumMenuFrame", "PlatinumDialogFrame", "Win98Window", "Win98MenuPanel",
                            "PlatinumMenuListRow", "Win98ListRow", "PlatinumIcon", "Win98Icon"]) {
            const object = Qt.createQmlObject('import QtQuick; import Hensou; ' + type + ' {}', first, type);
            verify(object !== null, type);
            object.destroy();
        }
        for (const count of [0, 1, 100]) {
            for (const type of ["PlatinumMenuList", "Win98ListView"]) {
                const object = Qt.createQmlObject('import QtQuick; import Hensou; ' + type +
                    ' { width: 200; height: 100; delegate: Item { width: 200; height: 30 } }', first, type);
                object.model = count;
                tryCompare(object, "count", count);
                object.currentIndex = count - 1;
                object.destroy();
            }
        }
    }
}
