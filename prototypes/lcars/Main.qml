// PROTOTYPE — LCARS spike for Hensou Files. Throwaway; see README.md.
// Interactive: ← and → switch variants. Render: --out file.png grabs one frame and quits.
import QtQuick
import "data.js" as Data

Window {
    id: win
    readonly property var argv: Qt.application.arguments
    function arg(name, def) {
        for (var i = 0; i < argv.length - 1; i++)
            if (argv[i] === "--" + name) return argv[i + 1];
        return def;
    }
    readonly property var variants: ["A", "B", "C"]
    property string variant: arg("variant", "A")
    readonly property string out: arg("out", "")
    width: Number(arg("w", 1280))
    height: Number(arg("h", 800))
    visible: true
    color: "#000000"
    title: "LCARS spike, variant " + variant

    FontLoader { id: antonio; source: "fonts/Antonio.ttf" }

    Loader {
        id: ld
        anchors.fill: parent
        anchors.margins: 8
        focus: true
        source: "Variant" + win.variant + ".qml"
        onLoaded: {
            item.fam = Qt.binding(function() { return antonio.name; });
            item.entries = Data.entries(win.arg("data", "ideal"));
            item.hosts = Data.hosts;
            item.menuOpen = win.arg("menu", "0") === "1";
        }
        Keys.onLeftPressed: win.variant = win.variants[(win.variants.indexOf(win.variant) + 2) % 3]
        Keys.onRightPressed: win.variant = win.variants[(win.variants.indexOf(win.variant) + 1) % 3]
    }

    Timer {
        interval: 500
        running: win.out !== ""
        onTriggered: win.contentItem.grabToImage(function(r) { r.saveToFile(win.out); Qt.quit(); })
    }
}
