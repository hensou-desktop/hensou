// PROTOTYPE — Variant B "Split": the TNG double frame. The upper frame is "where":
// hosts across the top, the path, the live transfer. The lower frame is "what":
// the list, with actions and readouts stacked in its arm.
import QtQuick
import "tokens.js" as T
import "plan.js" as Plan

Item {
    id: v
    property string fam: ""
    property var entries: []
    property var hosts: []
    property bool menuOpen: false
    readonly property var p: Plan.plan(width, height, hosts.length)
    readonly property real armW: p.rail ? Math.round(p.railW * 0.8) : 28
    readonly property real upperH: p.short ? 0 : Math.round(Math.max(170, Math.min(240, height * 0.27)))
    readonly property real seam: p.short ? 0 : 10
    readonly property real lowerY: upperH + seam
    readonly property real barH: p.short ? 14 : 18
    readonly property real elbowW: armW + 60
    readonly property real contentX: armW + 18
    readonly property real contentW: width - contentX - 8
    // Hosts across the upper frame: as many 150-px pills as fit, the rest in "More".
    readonly property int hostFit: Math.max(0, Math.floor((contentW - 110 - (p.rail ? 0 : 104)) / (150 + T.gap)))
    readonly property int hostsInline: Math.min(hosts.length, hostFit >= hosts.length ? hosts.length : Math.max(0, hostFit))
    readonly property real armBlockH: p.short ? 30 : 44

    // ── Upper frame ─────────────────────────────────────────────────
    Elbow {
        visible: v.upperH > 0
        corner: "bl"; armW: v.armW; barH: v.barH
        width: v.elbowW; height: v.upperH
        color: T.lilac
        outerR: Math.min(v.armW, v.upperH) * 0.6
    }
    Rectangle {
        // Rounded cap at the top of the upper arm.
        visible: v.upperH > 0
        width: v.armW; height: 26; color: T.lilac
        topLeftRadius: 13; topRightRadius: 13
    }
    Row {
        visible: v.upperH > 0
        x: v.elbowW + T.gap; y: v.upperH - v.barH; height: v.barH; spacing: T.gap
        readonly property real room: v.width - v.elbowW - T.gap * 3
        Rectangle { width: parent.room * 0.5; height: parent.height; color: T.lilac }
        Rectangle { width: parent.room * 0.15; height: parent.height; color: T.peach }
        Rectangle { width: parent.room * 0.35; height: parent.height; color: T.periwinkle; topRightRadius: height / 2; bottomRightRadius: height / 2 }
    }
    Column {
        visible: v.upperH > 0
        x: v.contentX; y: 4; width: v.contentW; spacing: 8
        Row {
            spacing: T.gap
            Repeater {
                model: v.hosts.slice(0, v.hostsInline)
                delegate: Pill {
                    required property var modelData
                    required property int index
                    width: 150; height: 40
                    leftCap: index === 0; rightCap: false
                    text: modelData.name; sub: modelData.detail; fam: v.fam
                    active: index === 0
                    color: modelData.detail === "Host key changed" || modelData.kind === "trash" ? T.alert
                         : modelData.kind === "ssh" ? T.periwinkle : T.sunset
                }
            }
            Pill {
                visible: v.hostsInline < v.hosts.length
                width: v.hostsInline === 0 ? 110 : 100; height: 40
                leftCap: v.hostsInline === 0
                text: v.hostsInline === 0 ? "Hosts" : "More (" + (v.hosts.length - v.hostsInline) + ")"
                fam: v.fam; color: T.peach
                onClicked: v.menuOpen = !v.menuOpen
            }
            Pill {
                // Narrow: the arm is too thin for labels, so actions move here whole.
                visible: !v.p.rail
                width: 100; height: 40; leftCap: false
                text: "Actions"; fam: v.fam; color: T.sunset
            }
        }
        Text {
            width: parent.width
            text: "home / simon / code / hensou"
            color: T.sunset; font.family: v.fam; font.weight: Font.Medium
            font.pixelSize: Math.round(Math.max(28, Math.min(56, v.upperH * 0.26)))
            elide: Text.ElideLeft
        }
        Row {
            spacing: T.gap; height: 20
            Rectangle { width: v.contentW * 0.4 * 0.62; height: 20; color: T.gold; topLeftRadius: 10; bottomLeftRadius: 10 }
            Rectangle { width: v.contentW * 0.4 * 0.38; height: 20; color: T.dim }
            Text {
                text: "62% copying 3 items, aka to myoko"
                width: v.contentW * 0.6 - T.gap * 2
                color: T.gold; font.family: v.fam; font.pixelSize: 18
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── Lower frame ─────────────────────────────────────────────────
    Elbow {
        id: lower
        y: v.lowerY
        corner: "tl"; armW: v.armW; barH: v.barH
        width: v.elbowW; height: v.barH + 50
        color: T.sunset
        outerR: Math.min(v.armW, 68) * 0.7
    }
    Row {
        x: v.elbowW + T.gap; y: v.lowerY; height: v.barH; spacing: T.gap
        readonly property real room: v.width - v.elbowW - T.gap * 3
        Rectangle { width: parent.room * 0.2; height: parent.height; color: T.peach }
        Rectangle { width: parent.room * 0.55; height: parent.height; color: T.sunset }
        Rectangle { width: parent.room * 0.25; height: parent.height; color: T.lilac; topRightRadius: height / 2; bottomRightRadius: height / 2 }
    }
    // Short windows lose the upper frame; its contents fold into one row here.
    Row {
        visible: v.p.short
        x: v.contentX; y: v.barH + 4; spacing: T.gap; height: 32
        Pill { width: 96; height: 32; text: "Hosts"; fam: v.fam; color: T.periwinkle; rightCap: false; onClicked: v.menuOpen = !v.menuOpen }
        Text {
            width: v.contentW - 96 - 70 - T.gap * 3
            text: "home / simon / code / hensou"; color: T.sunset; font.family: v.fam; font.pixelSize: 26
            elide: Text.ElideLeft; anchors.verticalCenter: parent.verticalCenter
        }
        Pill { width: 70; height: 32; text: "62%"; fam: v.fam; color: T.gold; leftCap: false }
    }
    Column {
        // Arm: actions first (controls), then readouts, then filler.
        x: 0; y: v.lowerY + lower.height + T.gap
        width: v.armW; spacing: T.gap
        readonly property bool labelled: v.p.rail
        Repeater {
            model: v.p.rail ? [
                { t: "Up", c: T.lilac }, { t: "New folder", c: T.peach }, { t: "Connect", c: T.sunset }
            ] : [ { t: "", c: T.sunset } ]
            delegate: Pill {
                required property var modelData
                width: v.armW; height: v.armBlockH; leftCap: false; rightCap: false
                text: modelData.t; fam: v.fam; color: modelData.c
            }
        }
        Repeater {
            model: v.p.rail && !v.p.short ? [
                { t: v.entries.length + " items", s: "Folder" },
                { t: "2.9 KB", s: "Selected" },
                { t: "214 GB", s: "Free" }
            ] : []
            delegate: Rectangle {
                required property var modelData
                width: v.armW; height: 54; color: T.dim
                Text { text: modelData.s.toUpperCase(); color: T.peach; font.family: v.fam; font.pixelSize: 12; x: 10; y: 4 }
                Text { text: modelData.t; color: T.peach; font.family: v.fam; font.pixelSize: 24; anchors.right: parent.right; anchors.rightMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 2 }
            }
        }
    }
    Rectangle {
        id: filler
        x: 0; width: v.armW; color: T.lilac
        y: v.lowerY + lower.height + T.gap + (v.p.rail ? 3 * (v.armBlockH + T.gap) + (v.p.short ? 0 : 3 * (54 + T.gap)) : v.armBlockH + T.gap)
        height: Math.max(0, v.height - y)
        bottomLeftRadius: Math.min(v.armW / 2, 20)
    }

    FileList {
        x: v.contentX
        y: v.lowerY + v.barH + (v.p.short ? 44 : 12)
        width: v.contentW
        height: v.height - y
        entries: v.entries; p: v.p; fam: v.fam
        accent: T.sunset
    }

    HostMenu {
        visible: v.menuOpen
        items: v.p.short ? v.hosts : v.hosts.slice(v.hostsInline)
        fam: v.fam
        width: Math.min(300, v.width - 16)
        x: Math.min(v.width - width - 8, v.contentX + v.hostsInline * 154)
        y: v.p.short ? 40 : 48
    }
}
