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
            PlatinumCheckBox { id: pcheck; text: "Keep draft"; interactive: true; onToggled: value => test.nextChecked = value }
            Win98Button { id: wbutton; text: "&Change value"; onClicked: test.clicks++ }
            Win98TextField { id: winput; Accessible.name: "Win98 draft" }
            Win98CheckBox { id: wcheck; text: "&Keep draft"; onToggled: value => test.nextChecked = value }
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

    function init() {
        clicks = 0; nextChecked = false;
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
            keyClick(Qt.Key_Space); keyClick(Qt.Key_Return);
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
            check.forceActiveFocus();
            keyClick(Qt.Key_Space);
            verify(nextChecked);
            compare(check.checked, false);
            nextChecked = false;
            waitForRendering(check);
            mouseClick(check, check.width / 2, check.height / 2);
            verify(nextChecked, "pointer " + check + " " + check.width + "x" + check.height);
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
