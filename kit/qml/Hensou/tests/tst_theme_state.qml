import QtQuick
import QtTest
import Hensou

TestCase {
    name: "ThemeStateContract"
    function cleanup() {
        Theme.appearance = "";
        Theme.mode = "dark";
        Theme.extraState = "off";
    }
    function test_legacy_mode_host() {
        compare(Theme.appearance, "");
        Theme.mode = "light";
        compare(Theme.dark, false);
        Theme.mode = "dark";
        compare(Theme.dark, true);
    }
    function test_host_owns_derived_mode() {
        Theme.appearance = "drawing-board";
        Theme.mode = "light";
        Theme.extraState = "on";
        compare(Theme.appearance, "drawing-board");
        compare(Theme.dark, false);
        // The stored preference stays on; each palette decides how to use it.
        compare(Theme.extraDark, true);
        Theme.appearance = "high-contrast-black";
        Theme.mode = "dark";
        compare(Theme.dark, true);
        compare(Theme.bgBase.toString(), "#000000");
    }
}
