// PROTOTYPE — one screen of an LCARS desktop. The shell draws the frame; apps tile
// inside it with no title bars. The arm is the window list: it replaces title bars,
// the taskbar and Platinum's window menu. Focus shows twice: a gold block in the arm
// and a gold Hyprland border on the tile.
import QtQuick
import "../tokens.js" as T
import "desktop-plan.js" as DP
import ".."

Item {
    id: d
    property string fam: ""
    property bool primary: true
    property string state_: "normal"          // normal | notify | switch
    property string screenName: "eDP-1"
    // Windows on this screen's current page, most recent first.
    property var windows: []
    property var pages: []                    // [{ n, label, current, count }]
    property int otherWindows: 0
    property Component tiles
    readonly property var p: DP.plan(width, height, primary)

    // ── Top elbow and bar ───────────────────────────────────────────
    Elbow {
        corner: "tl"; armW: d.p.armW; barH: d.p.topH
        width: d.p.elbowW; height: d.p.elbowH
        color: T.sunset
        outerR: Math.min(d.p.armW, d.p.elbowH) * 0.8
    }
    Text {
        // Screen name, written into the elbow like an LCARS section code.
        text: d.screenName.toUpperCase(); font.family: d.fam; font.pixelSize: 15; color: T.space
        x: d.p.armW - width - 12; y: d.p.elbowH - height - 4
    }
    Row {
        id: topRow
        x: d.p.elbowW + 4; height: d.p.topH; spacing: 4
        // Pages (Hyprland workspaces). The current one is gold.
        Repeater {
            model: d.pages
            delegate: Pill {
                required property var modelData
                width: 130; height: d.p.topH; leftCap: false; rightCap: false
                text: modelData.label; sub: modelData.count + (modelData.count === 1 ? " window" : " windows")
                color: modelData.current ? T.gold : T.lilac
                fam: d.fam; px: 18
            }
        }
        Rectangle {
            // Alert segment: dark until a notification arrives.
            width: Math.max(0, d.width - d.p.elbowW - 4 - d.pages.length * 134 - (d.p.clock ? 200 : 40))
            height: d.p.topH
            color: d.state_ === "notify" ? T.periwinkle : T.peach
            // Without title bars, the focused window's full title lives here.
            // A notification takes the segment over until it is read.
            readonly property var focusedWin: d.windows.filter(function (w) { return w.focused; })[0]
            Text {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                width: parent.width - 24; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                text: d.state_ === "notify" ? "1 NEW: BUILD FINISHED ON AKA"
                    : parent.focusedWin ? (parent.focusedWin.app + ": " + parent.focusedWin.title).toUpperCase() : ""
                color: T.space; font.family: d.fam; font.pixelSize: d.p.topH * 0.55
            }
        }
        Pill {
            visible: d.p.clock
            width: 196; height: d.p.topH; leftCap: false
            text: "21:47"; sub: "Thu 5 Nov"; color: T.sunset; fam: d.fam; px: 28
        }
        Rectangle {
            visible: !d.p.clock
            width: 36; height: d.p.topH; color: T.sunset
            topRightRadius: d.p.topH / 2; bottomRightRadius: d.p.topH / 2
        }
    }

    // ── Arm: the window list ────────────────────────────────────────
    Column {
        x: 0; y: d.p.elbowH + 4; width: d.p.armW; spacing: 4
        Repeater {
            model: d.windows.slice(0, d.p.blocksFit)
            delegate: Pill {
                required property var modelData
                width: d.p.armW; height: d.p.blockH; leftCap: false; rightCap: false
                text: modelData.title; sub: modelData.app
                color: modelData.focused ? T.gold : modelData.urgent ? T.alert : modelData.color
                fam: d.fam; px: 18
            }
        }
        Pill {
            visible: d.otherWindows > 0
            width: d.p.armW; height: d.p.blockH; leftCap: false; rightCap: false
            text: d.otherWindows + " on other pages"; sub: "Super+Tab"; color: T.dim; ink: T.peach
            fam: d.fam; px: 18
        }
    }
    Rectangle {
        x: 0; width: d.p.armW; color: T.lilac
        y: d.p.elbowH + 4 + (Math.min(d.windows.length, d.p.blocksFit) + (d.otherWindows > 0 ? 1 : 0)) * (d.p.blockH + 4)
        height: Math.max(0, d.height - y - d.p.bottomElbowH - 4)
        Text {
            // Launcher lives at the foot of the filler: Super+P opens the same.
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
            text: "OPEN APP  SUPER+P"; color: T.space; font.family: d.fam; font.pixelSize: 16
        }
    }

    // ── Bottom elbow and readouts ───────────────────────────────────
    Elbow {
        corner: "bl"; armW: d.p.armW; barH: d.p.bottomH
        y: d.height - d.p.bottomElbowH; width: d.p.elbowW; height: d.p.bottomElbowH
        color: T.sunset
    }
    Row {
        x: d.p.elbowW + 4; y: d.height - d.p.bottomH; height: d.p.bottomH; spacing: 4
        Repeater {
            model: d.p.readouts ? [
                { t: "Wi-Fi 82%", c: T.periwinkle, w: 150 },
                { t: "Volume 40%", c: T.lilac, w: 150 },
                { t: "Battery 71%", c: T.peach, w: 150 },
                { t: "Builds: aka idle", c: T.lilac, w: 200 },
                { t: "62% copying 3 items", c: T.gold, w: 230 }
            ] : [ { t: "Moonlight 1280×800", c: T.lilac, w: 240 } ]
            delegate: Rectangle {
                required property var modelData
                width: modelData.w; height: d.p.bottomH; color: modelData.c
                Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 1; text: modelData.t.toUpperCase(); color: T.space; font.family: d.fam; font.pixelSize: 18 }
            }
        }
        Rectangle {
            width: Math.max(0, d.width - d.p.elbowW - 4 - (d.p.readouts ? 880 + 20 : 244))
            height: d.p.bottomH; color: T.sunset
            topRightRadius: d.p.bottomH / 2; bottomRightRadius: d.p.bottomH / 2
        }
    }

    // ── Work area: tiled apps, no title bars ────────────────────────
    Loader {
        x: d.p.work.x; y: d.p.work.y; width: d.p.work.w; height: d.p.work.h
        sourceComponent: d.tiles
    }

    // ── Notification: a card under the lit alert segment ────────────
    Item {
        visible: d.state_ === "notify"
        width: 420; height: 176
        x: d.width - width - 14; y: d.p.topH + 6
        Rectangle { anchors.fill: parent; anchors.margins: -6; color: T.space; border.color: T.periwinkle; border.width: 2 }
        Rectangle { width: parent.width; height: 26; color: T.periwinkle; topLeftRadius: 13; bottomLeftRadius: 13
            Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 1; text: "FROM AKA, 21:46"; color: T.space; font.family: d.fam; font.pixelSize: 17 }
        }
        Rectangle { y: 30; width: 8; height: parent.height - 30; color: T.periwinkle }
        Text { x: 22; y: 38; text: "Build finished"; color: T.peach; font.family: d.fam; font.pixelSize: 30 }
        Text { x: 22; y: 80; width: parent.width - 34; wrapMode: Text.Wrap; text: "hensou-demo built in 41 s. 2 warnings."; color: T.peach; font.pixelSize: 16 }
        Row {
            x: 22; y: parent.height - 44; spacing: 4
            Pill { width: 150; height: 38; text: "Open log"; color: T.periwinkle; rightCap: false; fam: d.fam; px: 18 }
            Pill { width: 120; height: 38; text: "Dismiss"; color: T.dim; ink: T.peach; leftCap: false; fam: d.fam; px: 18 }
        }
    }

    // ── Super+Tab: every window, most recent first ──────────────────
    Rectangle {
        visible: d.state_ === "switch"
        x: d.p.work.x; y: d.p.work.y; width: d.p.work.w; height: d.p.work.h
        color: "#d0000000"
    }
    Item {
        visible: d.state_ === "switch"
        width: Math.min(760, d.p.work.w - 80); height: switchCol.height + 70
        x: d.p.work.x + (d.p.work.w - width) / 2; y: d.p.work.y + (d.p.work.h - height) / 2
        Rectangle { anchors.fill: parent; color: T.space }
        Elbow { corner: "tl"; armW: 90; barH: 26; width: 200; height: 70; color: T.sunset }
        Rectangle { x: 204; width: parent.width - 204; height: 26; color: T.sunset; topRightRadius: 13; bottomRightRadius: 13
            Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 1; text: "SWITCH WINDOW"; color: T.space; font.family: d.fam; font.pixelSize: 20 }
        }
        Rectangle { y: 74; width: 90; height: parent.height - 74; color: T.lilac; bottomLeftRadius: 24 }
        Column {
            id: switchCol
            x: 104; y: 40; width: parent.width - 108; spacing: 4
            Repeater {
                model: [
                    { app: "Chromium", title: "Window rules – Hyprland Wiki", page: "Page 1 Work", sel: false },
                    { app: "Files", title: "hensou", page: "Page 1 Work", sel: true },
                    { app: "Ghostty", title: "nix build", page: "Page 1 Work", sel: false },
                    { app: "Pyxamp", title: "Boards of Canada – Roygbiv", page: "Page 2 Media", sel: false },
                    { app: "Chromium", title: "Forgerie", page: "Page 3 Agents", sel: false },
                    { app: "Ghostty", title: "ssh myoko", page: "Tablet", sel: false }
                ]
                delegate: Item {
                    required property var modelData
                    width: switchCol.width; height: 48
                    Pill {
                        width: 150; height: 48; rightCap: false; leftCap: false
                        text: modelData.app; sub: modelData.page; fam: d.fam; px: 18
                        color: modelData.sel ? T.gold : T.periwinkle
                    }
                    Rectangle {
                        x: 154; width: parent.width - 154; height: 48
                        color: modelData.sel ? T.gold : "transparent"
                        topRightRadius: 24; bottomRightRadius: 24
                        Text { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 40; elide: Text.ElideRight
                            text: modelData.title; color: modelData.sel ? T.space : T.peach; font.family: d.fam; font.pixelSize: 24 }
                    }
                }
            }
        }
    }
}
