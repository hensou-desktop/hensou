// PROTOTYPE — LCARS desktop mock. --state normal | notify | switch | dual
// Render: --out file.png. Sizes are logical pixels; Myoko's real size is a guess.
import QtQuick
import "../tokens.js" as T

Window {
    id: win
    readonly property var argv: Qt.application.arguments
    function arg(name, def) {
        for (var i = 0; i < argv.length - 1; i++)
            if (argv[i] === "--" + name) return argv[i + 1];
        return def;
    }
    readonly property string st: arg("state", "normal")
    readonly property bool dual: st === "dual"
    readonly property int sw: Number(arg("w", 1920))
    readonly property int sh: Number(arg("h", 1080))
    readonly property string out: arg("out", "")
    width: sw
    height: dual ? sh + 40 + 800 : sh
    visible: true
    color: dual ? "#1a1a1a" : "#000000"

    FontLoader { id: antonio; source: "../fonts/Antonio.ttf" }

    readonly property var mainWindows: [
        { app: "Files", title: "hensou", focused: true, color: T.lilac },
        { app: "Chromium", title: "Window rules – Hyprland Wiki", focused: false, color: T.periwinkle },
        { app: "Ghostty", title: "nix build", focused: false, color: T.peach }
    ]
    readonly property var mainPages: [
        { label: "1 Work", current: true, count: 3 },
        { label: "2 Media", current: false, count: 1 },
        { label: "3 Agents", current: false, count: 1 }
    ]

    // Tiles on the laptop: browser left, Files and terminal stacked right.
    Component {
        id: mainTiles
        Item {
            id: wa
            readonly property real g: 10
            readonly property real leftW: Math.round(width * 0.56)
            WebPage { width: wa.leftW; height: wa.height; fam: antonio.name }
            FilesPane {
                id: files
                x: wa.leftW + wa.g; width: wa.width - wa.leftW - wa.g; height: Math.round(wa.height * 0.58)
                fam: antonio.name
            }
            Terminal { id: term; x: files.x; y: files.height + wa.g; width: files.width; height: wa.height - files.height - wa.g }
            Repeater {
                // Inactive border: black apps on a black frame need an edge.
                model: [ { x: 0, y: 0, w: wa.leftW, h: wa.height }, { x: term.x, y: term.y, w: term.width, h: term.height } ]
                delegate: Rectangle {
                    required property var modelData
                    x: modelData.x - 2; y: modelData.y - 2; width: modelData.w + 4; height: modelData.h + 4
                    color: "transparent"; border.color: T.dim; border.width: 2
                }
            }
            Rectangle {
                // Focus: Hyprland's active border, in gold. Nothing else marks a tile.
                x: files.x - 3; y: -3; width: files.width + 6; height: files.height + 6
                color: "transparent"; border.color: T.gold; border.width: 3
            }
        }
    }
    Component {
        id: tabletTiles
        Item {
            Terminal { anchors.fill: parent }
            Rectangle { x: -2; y: -2; width: parent.width + 4; height: parent.height + 4; color: "transparent"; border.color: T.dim; border.width: 2 }
        }
    }

    Desktop {
        id: mainDesk
        width: win.sw; height: win.sh
        fam: antonio.name
        primary: true
        screenName: "eDP-1"
        state_: win.dual ? "normal" : win.st
        windows: mainWindows
        pages: mainPages
        otherWindows: 2
        tiles: mainTiles
    }

    // Second screen: the Moonlight tablet below the laptop.
    Text {
        visible: win.dual
        x: (win.sw - 1280) / 2; y: win.sh + 10
        text: "Tablet below the laptop (SUNSHINE output, 1280×800). One clock and one set of readouts, on the laptop only."
        color: "#888888"; font.pixelSize: 16
    }
    Desktop {
        visible: win.dual
        x: (win.sw - 1280) / 2; y: win.sh + 40
        width: 1280; height: 800
        fam: antonio.name
        primary: false
        screenName: "Sunshine"
        windows: [ { app: "Ghostty", title: "ssh myoko", focused: false, color: T.peach } ]
        pages: [ { label: "4 Tablet", current: true, count: 1 } ]
        tiles: tabletTiles
    }

    Timer {
        interval: 700
        running: win.out !== ""
        onTriggered: win.contentItem.grabToImage(function(r) { r.saveToFile(win.out); Qt.quit(); })
    }
}
