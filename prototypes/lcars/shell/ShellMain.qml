// PROTOTYPE — the LCARS shell sweep. Myoko is a logical 1920×1200 (2880×1800 at 1.5);
// the portable monitor sits above it at the same size; the tablet below is 1280×800.
// --state calm | warn | chord | system | sound | wifi | layout | find | switch |
//         glance | dictation | notify | unread | critical | shutdown | dual | small
import QtQuick
import "../tokens.js" as T
import "../desktop"

Window {
    id: win
    readonly property var argv: Qt.application.arguments
    function arg(name, def) {
        for (var i = 0; i < argv.length - 1; i++) if (argv[i] === "--" + name) return argv[i + 1];
        return def;
    }
    readonly property string st: arg("state", "calm")
    readonly property bool dual: st === "dual"
    readonly property bool small: st === "small"
    readonly property int sw: small ? 1280 : 1920
    readonly property int sh: small ? 800 : 1200
    readonly property string out: arg("out", "")
    width: sw
    height: dual ? sh * 2 + 30 : sh
    visible: true
    color: dual ? "#1a1a1a" : "#000000"
    FontLoader { id: antonio; source: "../fonts/Antonio.ttf" }

    readonly property var laptopPages: [
        { current: true, windows: [
            { app: "Files", title: "hensou", focused: true, color: T.lilac },
            { app: "Chromium", title: "Window rules – Hyprland Wiki", color: T.sunset },
            { app: "Ghostty", title: "nix build", color: T.peach } ] },
        { windows: [
            { app: "Pyxamp", title: "Boards of Canada – Roygbiv", color: T.lilac },
            { app: "Chromium", title: "Forgerie", color: T.sunset } ] },
        { windows: [
            { app: "Signal", title: "Laure", hidden: true, color: T.peach },
            { app: "Zed", title: "shell.qml", color: T.sunset } ] }
    ]
    readonly property var externalPages: [
        { current: true, windows: [ { app: "Chromium", title: "Jellyfin", color: T.sunset }, { app: "Ghostty", title: "ssh aka", color: T.peach } ] }
    ]

    Component {
        id: workTiles
        Item {
            id: wa
            readonly property real g: 10
            readonly property real leftW: Math.round(width * 0.56)
            WebPage { width: wa.leftW; height: wa.height; fam: antonio.name; themed: false }
            FilesPane { id: files; x: wa.leftW + wa.g; width: wa.width - wa.leftW - wa.g; height: Math.round(wa.height * 0.58); fam: antonio.name }
            Terminal { id: term; x: files.x; y: files.height + wa.g; width: files.width; height: wa.height - files.height - wa.g }
            Repeater {
                model: [ { x: 0, y: 0, w: wa.leftW, h: wa.height }, { x: term.x, y: term.y, w: term.width, h: term.height } ]
                delegate: Rectangle { required property var modelData; x: modelData.x - 2; y: modelData.y - 2; width: modelData.w + 4; height: modelData.h + 4; color: "transparent"; border.color: T.dim; border.width: 2 }
            }
            Rectangle { x: files.x - 3; y: -3; width: files.width + 6; height: files.height + 6; color: "transparent"; border.color: T.gold; border.width: 3 }
        }
    }
    Component {
        id: externalTiles
        Item {
            id: ex
            Rectangle {
                // A video page, untouched: the web theme is postponed.
                width: ex.width * 0.62; height: ex.height; color: "#101010"
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.86; height: width * 9 / 16; color: "#2b3a4a"
                    Text { anchors.centerIn: parent; text: "▶  Jellyfin"; color: "#cfd8e3"; font.pixelSize: 28 } }
                Rectangle { x: -2; y: -2; width: parent.width + 4; height: parent.height + 4; color: "transparent"; border.color: T.dim; border.width: 2 }
            }
            Terminal { x: ex.width * 0.62 + 10; width: ex.width * 0.38 - 10; height: ex.height }
            Rectangle { x: ex.width * 0.62 + 8; y: -2; width: ex.width * 0.38 - 6; height: ex.height + 4; color: "transparent"; border.color: T.dim; border.width: 2 }
        }
    }

    LcarsScreen {
        id: top
        visible: win.dual
        width: win.sw; height: win.sh
        fam: antonio.name; st: "calm"; screenName: "DP-3 above"
        pages: win.externalPages; tiles: externalTiles
    }
    Text { visible: win.dual; x: 20; y: win.sh + 6; text: "Portable monitor above, laptop panel below. Both a logical 1920×1200; each screen keeps its own windows and its own frame."; color: "#888888"; font.pixelSize: 15 }
    LcarsScreen {
        y: win.dual ? win.sh + 30 : 0
        width: win.sw; height: win.sh
        fam: antonio.name; st: win.dual ? "calm" : win.st; screenName: "eDP-1"
        pages: win.laptopPages; tiles: workTiles
    }

    Timer { interval: 900; running: win.out !== ""; onTriggered: win.contentItem.grabToImage(function(r) { r.saveToFile(win.out); Qt.quit(); }) }
}
