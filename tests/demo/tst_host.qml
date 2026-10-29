import QtQuick
import QtTest
import Hensou
import Hensou.Host
import Hensou.Demo

TestCase {
    name: "HostRuntime"
    when: windowShown
    width: 32
    height: 32
    Component { id: windowComponent; DemoWindow {} }
    Component { id: mainComponent; Main { title: "Hensou live host" } }
    function phase(name) { console.log("HENSOU_PHASE " + name); }
    function test_appearance_files_and_real_window_scale() {
        const live = createTemporaryObject(mainComponent, null);
        verify(live);
        live.state.text = "preserved draft";
        live.state.checked = true;
        live.state.selectedIndex = 7;
        wait(80);
        compare(HostTheme.name, "platinum");
        compare(HostTheme.mode, "dark");
        compare(HostTheme.extraState, "off");
        phase("create");
        tryCompare(HostTheme, "name", "win98");
        tryCompare(HostTheme, "mode", "light");
        tryCompare(HostTheme, "extraState", "on");
        compare(Theme.name, "win98");
        compare(findChild(live, "editableInput").text, "preserved draft");
        compare(live.state.checked, true);
        compare(live.state.selectedIndex, 7);
        phase("invalid");
        tryCompare(HostTheme, "name", "platinum");
        tryCompare(HostTheme, "extraState", "off");
        compare(HostTheme.mode, "light");
        phase("missing");
        wait(150);
        compare(HostTheme.name, "platinum");
        compare(HostTheme.mode, "light");
        compare(HostTheme.extraState, "off");
        phase("atomic");
        tryCompare(HostTheme, "mode", "dark");
        tryCompare(HostTheme, "extraState", "on");
        phase("recreate");
        tryCompare(HostTheme, "name", "win98");
        tryCompare(HostTheme, "mode", "light");
        live.close();
        live.destroy();
        wait(30);
        Theme.name = "win98";
        const one = createTemporaryObject(windowComponent, null, { title: "Hensou scale one" });
        const fractional = createTemporaryObject(windowComponent, null, { title: "Hensou scale fractional" });
        verify(one); verify(fractional);
        wait(150);
        phase("scales");
        tryCompare(one, "actualDpr", 1);
        tryCompare(fractional, "actualDpr", 1.5);
        const oneButton = findChild(one, "incrementButton");
        const secondButton = findChild(fractional, "incrementButton");
        compare(oneButton.item.u * one.actualDpr, Math.round(oneButton.item.u * one.actualDpr));
        compare(secondButton.item.u * fractional.actualDpr, Math.round(secondButton.item.u * fractional.actualDpr));
        const firstUnit = oneButton.item.u;
        phase("rescale");
        tryCompare(fractional, "actualDpr", 2);
        compare(one.actualDpr, 1);
        compare(oneButton.item.u, firstUnit);
        compare(secondButton.item.u, 1);
        phase("restore-scale");
        tryCompare(fractional, "actualDpr", 1.5);
        one.close(); fractional.close();
    }
    function test_five_appearance_captures_and_shapes() {
        const app = createTemporaryObject(windowComponent, null, { title: "Hensou capture" });
        verify(app);
        for (const appearance of [["platinum", "light", "off"], ["platinum", "dark", "off"], ["platinum", "dark", "on"], ["win98", "light", "off"], ["win98", "dark", "off"]]) {
            Theme.name = appearance[0]; Theme.mode = appearance[1]; Theme.extraState = appearance[2];
            const tag = appearance[0] + "-" + appearance[1] + (appearance[2] === "on" ? "-extra" : "");
            for (const shape of [[220, 640, "narrow"], [1000, 180, "wide"]]) {
                app.width = shape[0]; app.height = shape[1];
                app.fixture(shape[2] === "narrow" ? 100 : 1);
                phase("prepare-capture-" + shape[2]);
                wait(300);
                compare(app.width, shape[0]); compare(app.height, shape[1]);
                compare(app.actualDpr, 1.5);
                console.log("HENSOU_GEOMETRY", app.width, app.height, app.actualDpr);
                phase("capture-" + tag + "-" + shape[2]);
                wait(100);
            }
        }
        app.close();
    }
}
