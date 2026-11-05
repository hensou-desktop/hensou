// PROTOTYPE — Variant A "Console": the canonical LCARS frame. Hosts live in the left
// arm of one elbow; the transfer readout runs along the bottom elbow.
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
    readonly property real armW: p.rail ? p.railW : 28
    readonly property real topBarH: p.short ? 14 : 22
    readonly property real elbowW: armW + (p.rail ? 70 : 40)
    readonly property real elbowH: topBarH + p.headerH
    readonly property real bottomH: p.footerH > 0 ? p.footerH + 34 : 0
    readonly property real contentX: armW + 18

    // ── Top elbow and bar ───────────────────────────────────────────
    Elbow {
        id: top
        corner: "tl"; armW: v.armW; barH: v.topBarH
        width: v.elbowW; height: v.elbowH
        color: T.sunset; fam: v.fam
        label: v.p.rail && !v.p.short ? "Files" : ""
    }
    Row {
        x: v.elbowW + T.gap; y: 0; spacing: T.gap
        height: v.topBarH
        Rectangle { width: Math.max(0, (v.width - v.elbowW) * 0.38); height: parent.height; color: T.peach }
        Rectangle { width: Math.max(0, (v.width - v.elbowW) * 0.14); height: parent.height; color: T.lilac }
        Pill {
            width: Math.max(0, v.width - v.elbowW - T.gap * 4 - (v.width - v.elbowW) * 0.52)
            height: parent.height; leftCap: false; color: T.periwinkle
            text: v.p.short ? "" : v.entries.length + " items"; fam: v.fam; px: Math.round(v.topBarH * 0.8)
        }
    }

    // ── Header: where you are, and what you can do ──────────────────
    Item {
        x: v.contentX; y: v.topBarH + 6
        width: v.width - v.contentX - 8; height: v.p.headerH - 10
        Text {
            id: title
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - actions.width - 16
            text: (v.p.rail ? "" : "This computer / ") + "home / simon / code / hensou"
            color: T.sunset
            font.family: v.fam; font.pixelSize: Math.min(v.p.titlePx, Math.round((v.width - v.contentX) / 11)); font.weight: Font.Medium
            elide: Text.ElideLeft
        }
        Row {
            id: actions
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: T.gap
            Pill { visible: !v.p.rail; width: 96; height: v.p.pillH; text: "Hosts"; fam: v.fam; color: T.periwinkle; rightCap: false; onClicked: v.menuOpen = !v.menuOpen }
            Pill { visible: v.p.actionsInline; width: 80; height: v.p.pillH; text: "Up"; fam: v.fam; color: T.lilac; rightCap: false }
            Pill { visible: v.p.actionsInline; width: 120; height: v.p.pillH; text: "New folder"; fam: v.fam; color: T.peach; leftCap: false; rightCap: false }
            Pill { visible: v.p.actionsInline; width: 110; height: v.p.pillH; text: "Connect"; fam: v.fam; color: T.sunset; leftCap: false }
            Pill { visible: !v.p.actionsInline; width: 100; height: v.p.pillH; text: "Actions"; fam: v.fam; color: T.sunset; leftCap: v.p.rail }
            Pill { visible: v.p.footerH === 0; width: 70; height: v.p.pillH; text: "62%"; fam: v.fam; color: T.gold; leftCap: false }
        }
    }

    // ── Left arm: hosts, then a filler block down to the bottom elbow ─
    Column {
        visible: v.p.rail
        x: 0; y: v.elbowH + T.gap
        width: v.armW; spacing: T.gap
        Repeater {
            model: v.hosts.slice(0, v.p.hostsInline)
            delegate: Pill {
                required property var modelData
                required property int index
                width: v.armW; height: v.p.pillH
                leftCap: false; rightCap: false
                text: modelData.name; sub: modelData.detail; fam: v.fam
                active: index === 0
                color: modelData.detail === "Host key changed" || modelData.kind === "trash" ? T.alert
                     : modelData.kind === "ssh" ? T.periwinkle : T.sunset
            }
        }
        Pill {
            visible: v.p.hostsOverflow > 0
            width: v.armW; height: v.p.pillH; leftCap: false; rightCap: false
            text: "More (" + v.p.hostsOverflow + ")"; fam: v.fam; color: T.peach
            onClicked: v.menuOpen = !v.menuOpen
        }
    }
    Rectangle {
        visible: v.p.rail
        x: 0; width: v.armW
        y: v.elbowH + T.gap + (v.p.hostsInline + (v.p.hostsOverflow > 0 ? 1 : 0)) * (v.p.pillH + T.gap)
        height: Math.max(0, v.height - y - v.bottomH - T.gap)
        color: T.lilac
    }
    Rectangle {
        // Narrow: the arm is pure frame.
        visible: !v.p.rail
        x: 0; y: v.elbowH + T.gap; width: v.armW
        height: Math.max(0, v.height - y - v.bottomH - T.gap)
        color: T.lilac
    }

    // ── Bottom elbow: transfer readout ──────────────────────────────
    Elbow {
        visible: v.bottomH > 0
        corner: "bl"; armW: v.armW; barH: v.p.footerH
        y: v.height - v.bottomH; width: v.elbowW; height: v.bottomH
        color: T.sunset
    }
    Row {
        visible: v.bottomH > 0
        x: v.elbowW + T.gap; y: v.height - v.p.footerH
        height: v.p.footerH; spacing: T.gap
        readonly property real room: v.width - v.elbowW - T.gap * 3
        Rectangle { width: parent.room * 0.62 * 0.5; height: parent.height; color: T.gold }
        Rectangle { width: parent.room * 0.38 * 0.5; height: parent.height; color: T.dim }
        Pill {
            width: parent.room * 0.5; height: parent.height; leftCap: false; color: T.peach
            text: "62% copying 3 items, aka to myoko"; fam: v.fam; px: 18
        }
    }

    FileList {
        x: v.contentX; y: v.elbowH + 8
        width: v.width - v.contentX - 8
        height: v.height - y - v.bottomH - 8
        entries: v.entries; p: v.p; fam: v.fam
    }

    HostMenu {
        visible: v.menuOpen
        items: v.p.rail ? v.hosts.slice(v.p.hostsInline) : v.hosts
        fam: v.fam
        x: v.p.rail ? v.armW + 8 : Math.max(8, v.width - width - 8)
        y: v.p.rail ? Math.min(v.height - height - 8, v.elbowH + v.p.hostsInline * (v.p.pillH + T.gap)) : v.elbowH
        width: Math.min(300, v.width - 16)
    }
}
