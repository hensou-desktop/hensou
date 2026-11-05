// PROTOTYPE — one screen of the LCARS shell, mapped from the live Platinum and
// Windows 98 desktops (see INVENTORY.md). The frame is the bar, the menus,
// the Control Strip / taskbar and the notification surface at once.
import QtQuick
import "../tokens.js" as T
import "shell-plan.js" as SP
import ".."

Item {
    id: s
    property string fam: ""
    property bool primary: true
    property string st: "calm"
    property string host: "myoko"
    property string screenName: "eDP-1"
    // Pages on this screen, in strip order. No page numbers, ever.
    property var pages: []
    property Component tiles
    readonly property var f: SP.frame(width, height)
    readonly property real armBottom: arm.y + arm.height

    readonly property bool warn: st === "warn"
    readonly property bool critical: st === "critical"
    readonly property color c1: critical ? T.alert : T.sunset
    readonly property color c2: critical ? "#993333" : T.lilac

    // ── Bar data: the live bar's controls, quiet until they warn ─────
    function seg(id, label, value, color) {
        var text = value ? label + " " + value : label;
        return { id: id, label: label, value: value, color: color, w: Math.round(text.length * 10.5 + 34) };
    }
    readonly property var controls: [
        seg("layout", "Tiled", "", T.lilac),
        seg("bt", "BT", "", T.periwinkle),
        seg("wifi", "Wi-Fi", "", T.periwinkle),
        seg("vol", "Vol", st === "sound" ? "40" : "", T.peach),
        seg("bri", "Bri", "", T.peach),
        seg("oci", "Cloud", warn ? "63%" : "", warn ? T.gold : T.lilac),
        seg("disk", "Disks", warn ? "1 issue" : "", warn ? T.gold : T.lilac),
        seg("fleet", "Fleet", warn ? "1 down" : "", warn ? T.alert : T.lilac),
        seg("builder", "Builds", warn ? "off: battery" : "", warn ? T.gold : T.lilac),
        seg("ntf", "Comms", (st === "unread" || warn) ? "2" : "", T.periwinkle)
    ]
    readonly property real barX: f.elbowW + 4
    readonly property real battW: 70
    readonly property var bar: SP.bar(width - barX - battW - 4, primary ? controls : [], primary ? 150 : 0, 220)
    function segX(id) {
        for (var i = 0; i < bar.segs.length; i++) if (bar.segs[i].c.id === id) return barX + bar.segs[i].x;
        return barX + bar.moreX;
    }
    readonly property var focusedWin: {
        for (var i = 0; i < pages.length; i++)
            for (var j = 0; j < pages[i].windows.length; j++)
                if (pages[i].windows[j].focused) return pages[i].windows[j];
        return null;
    }

    // ── Top elbow: the system menu (the Apple menu / Start button) ──
    Elbow {
        corner: "tl"; armW: s.f.armW; barH: s.f.topH
        width: s.f.elbowW; height: s.f.elbowH; color: s.st === "system" ? T.gold : s.c1
        outerR: Math.min(s.f.armW, s.f.elbowH) * 0.8
    }
    Text { text: s.host.toUpperCase(); font.family: s.fam; font.pixelSize: 26; color: T.space; x: s.f.armW - width - 12; y: s.f.elbowH - height - 2 }
    Text { text: s.screenName.toUpperCase(); font.family: s.fam; font.pixelSize: 13; color: T.space; x: 18; y: 8 }

    // ── Top bar ─────────────────────────────────────────────────────
    Rectangle {
        // Title segment: what the title bars used to say. During the Super+O
        // chord it says which keys are live.
        x: s.barX; width: s.bar.titleW; height: s.f.topH
        color: s.critical ? T.alert : s.st === "chord" ? T.gold : T.peach
        Text {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 2
            width: parent.width - 24; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
            text: s.critical ? "ALERT: STORAGE ALMOST FULL ON AKA"
                : s.st === "chord" ? "SUPER+O: CHOOSE A CONTROL"
                : s.focusedWin ? (s.focusedWin.app + ": " + s.focusedWin.title).toUpperCase() : ""
            color: T.space; font.family: s.fam; font.pixelSize: s.f.topH * 0.55
        }
    }
    Repeater {
        model: s.bar.segs
        delegate: Rectangle {
            required property var modelData
            readonly property var c: modelData.c
            readonly property bool open: s.st === "sound" && c.id === "vol" || s.st === "wifi" && c.id === "wifi" || s.st === "layout" && c.id === "layout" || s.st === "glance" && c.id === "fleet"
            x: s.barX + modelData.x; width: c.w; height: s.f.topH
            color: open ? T.gold : c.color
            Text { visible: s.st === "chord"; x: 6; y: 2; text: ({ bt: "B", wifi: "W", vol: "S", bri: "L", oci: "C", disk: "D", fleet: "F", builder: "R", layout: "Y", ntf: "N" })[parent.c.id] || ""; color: T.space; font.family: s.fam; font.pixelSize: 20; font.bold: true }
            Text { anchors.right: parent.right; anchors.rightMargin: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 2; text: (parent.c.label + (parent.c.value ? " " + parent.c.value : "")).toUpperCase(); color: T.space; font.family: s.fam; font.pixelSize: 19 }
        }
    }
    Rectangle {
        visible: s.bar.more.length > 0
        x: s.barX + s.bar.moreX; width: 96; height: s.f.topH; color: T.dim
        Text { anchors.right: parent.right; anchors.rightMargin: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 2; text: "MORE " + s.bar.more.length; color: T.peach; font.family: s.fam; font.pixelSize: 19 }
    }
    Rectangle {
        visible: s.primary
        x: s.barX + s.bar.clockX; width: 150; height: s.f.topH; color: s.c1
        Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 0; text: "21:47"; color: T.space; font.family: s.fam; font.pixelSize: s.f.topH * 0.8 }
    }
    Rectangle {
        // Battery: the end cap. Its fill is the charge; a number only when low.
        x: s.width - s.battW; width: s.battW; height: s.f.topH; color: s.primary ? T.dim : s.c1
        topRightRadius: s.f.topH / 2; bottomRightRadius: s.f.topH / 2
        Rectangle { visible: s.primary; width: parent.width * (s.st === "warn" ? 0.09 : 0.71); height: parent.height; color: s.st === "warn" ? T.alert : T.periwinkle }
        Text { visible: s.primary && s.st === "warn"; anchors.centerIn: parent; text: "9%"; color: T.space; font.family: s.fam; font.pixelSize: 18 }
    }

    // ── Arm: every window on this screen, page by page ──────────────
    Column {
        id: arm
        x: 0; y: s.f.elbowH + 4; width: s.f.armW; spacing: 4
        Repeater {
            model: s.pages
            delegate: Column {
                id: pageCol
                required property var modelData
                required property int index
                width: s.f.armW; spacing: 4
                Rectangle {
                    // Page divider: a slim bar, no number.
                    visible: pageCol.index > 0
                    width: s.f.armW; height: 10; color: s.c2
                }
                Repeater {
                    model: pageCol.modelData.windows
                    delegate: Pill {
                        required property var modelData
                        width: s.f.armW; height: s.f.blockH; leftCap: false; rightCap: false
                        text: modelData.title
                        sub: modelData.hidden ? modelData.app + ", hidden" : modelData.app
                        color: modelData.focused ? T.gold : (pageCol.modelData.current && !modelData.hidden) ? modelData.color : T.dim
                        ink: modelData.focused || (pageCol.modelData.current && !modelData.hidden) ? T.space : T.peach
                        fam: s.fam; px: 18
                    }
                }
            }
        }
        Pill {
            // Comms lives in the arm, under the windows.
            visible: s.st === "unread" || s.warn
            width: s.f.armW; height: s.f.blockH; leftCap: false; rightCap: false
            text: "2 unread"; sub: "Comms"; color: T.periwinkle; fam: s.fam; px: 18
        }
    }
    Rectangle {
        x: 0; y: arm.y + arm.height + 4; width: s.f.armW
        height: Math.max(0, s.height - y - s.f.bottomElbowH - 4)
        color: s.st === "dictation" ? T.alert : s.c2
        Text {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
            text: s.st === "dictation" ? "LISTENING" : ""; color: T.space; font.family: s.fam; font.pixelSize: 22
        }
        // Dictation: the live input level climbs the arm.
        Column {
            visible: s.st === "dictation"
            anchors.horizontalCenter: parent.horizontalCenter; y: 14; spacing: 3
            Repeater {
                model: [0.3, 0.55, 0.8, 0.95, 0.7, 0.5, 0.85, 0.6, 0.35, 0.65, 0.9, 0.45]
                delegate: Rectangle { required property real modelData; width: (s.f.armW - 40) * modelData; height: 10; color: T.space; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }

    // ── Bottom elbow and bar ────────────────────────────────────────
    Elbow {
        corner: "bl"; armW: s.f.armW; barH: s.f.bottomH
        y: s.height - s.f.bottomElbowH; width: s.f.elbowW; height: s.f.bottomElbowH; color: s.c1
    }
    Row {
        id: bottomRow
        x: s.f.elbowW + 4; y: s.height - s.f.bottomH; height: s.f.bottomH; spacing: 4
        readonly property var items: s.st === "chord" ? [
                { t: "B Bluetooth", c: T.periwinkle }, { t: "W Wi-Fi", c: T.periwinkle }, { t: "S Sound", c: T.peach },
                { t: "L Brightness", c: T.peach }, { t: "C Cloud", c: T.lilac }, { t: "D Disks", c: T.lilac },
                { t: "F Fleet", c: T.lilac }, { t: "R Builds", c: T.lilac }, { t: "Y Layout", c: T.lilac }, { t: "N Comms", c: T.periwinkle } ]
            : s.st === "dictation" ? [ { t: "Right Alt held: dictating into Ghostty", c: T.alert }, { t: "Release to insert", c: T.peach } ]
            : s.primary ? [ { t: "62% copying 3 items to myoko", c: T.gold } ] : []
        Repeater {
            model: parent.items
            delegate: Rectangle {
                required property var modelData
                width: txt.width + 30; height: s.f.bottomH; color: modelData.c
                Text { id: txt; anchors.right: parent.right; anchors.rightMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 1; text: modelData.t.toUpperCase(); color: T.space; font.family: s.fam; font.pixelSize: 18 }
            }
        }
    }
    Rectangle {
        x: bottomRow.x + bottomRow.width + (bottomRow.width > 0 ? 4 : 0); y: bottomRow.y
        width: Math.max(40, s.width - x)
        height: s.f.bottomH; color: s.c1
        topRightRadius: s.f.bottomH / 2; bottomRightRadius: s.f.bottomH / 2
    }

    // ── Work area ───────────────────────────────────────────────────
    Loader { x: s.f.work.x; y: s.f.work.y; width: s.f.work.w; height: s.f.work.h; sourceComponent: s.tiles }

    // ── Overlays by state ───────────────────────────────────────────
    Loader {
        anchors.fill: parent
        active: ["system", "sound", "wifi", "layout", "find", "switch", "glance", "notify", "critical", "shutdown"].indexOf(s.st) >= 0
        source: ({ system: "SystemPanel.qml", sound: "SoundPanel.qml", wifi: "WifiPanel.qml", layout: "LayoutPanel.qml",
                   find: "FindConsole.qml", switch: "AppSwitch.qml", glance: "Glance.qml", notify: "CommsSlab.qml",
                   critical: "CommsSlab.qml", shutdown: "ShutdownPanel.qml" })[s.st] || ""
        onLoaded: item.screen = s
    }
}
