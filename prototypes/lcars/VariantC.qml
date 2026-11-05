// PROTOTYPE — Variant C "PADD": no elbows. The path is a segmented pill bar you can
// click, folders open as Miller columns, and hosts sit in a console strip at the bottom.
import QtQuick
import "tokens.js" as T
import "plan.js" as Plan
import "data.js" as Data

Item {
    id: v
    property string fam: ""
    property var entries: []
    property var hosts: []
    property bool menuOpen: false
    readonly property var p: Plan.plan(width, height, hosts.length)
    readonly property var crumbs: ["This computer", "home", "simon", "code", "hensou"]
    readonly property real crumbH: p.short ? 32 : 48
    readonly property real stripH: p.short ? 32 : 44
    readonly property real colTop: crumbH + 14
    readonly property real colBottom: height - stripH - 12
    readonly property int cols: p.millerCols
    readonly property real sideColW: 210
    readonly property real lastColW: width - (cols - 1) * (sideColW + 10)
    // Breadcrumb segments that fit at ~130 px each; the head folds into "…".
    readonly property int crumbFit: Math.max(1, Math.floor((width - 140 - 120 - (p.actionsInline ? 3 * 124 : 0)) / 154))
    readonly property int crumbsInline: Math.min(crumbs.length, crumbFit)
    // Bottom strip: host pills at 140 px, transfer readout keeps 180 px.
    readonly property int hostFit: Math.max(0, Math.floor((width - 230 - 110) / 144))
    readonly property int hostsInline: hostFit >= hosts.length ? hosts.length : hostFit

    // ── Path bar ────────────────────────────────────────────────────
    Row {
        spacing: T.gap; height: v.crumbH
        Pill {
            width: 120; height: v.crumbH; rightCap: false
            text: v.p.actionsInline ? "Files" : "Actions"; sub: v.p.actionsInline ? "" : ""
            fam: v.fam; color: T.sunset
        }
        Pill {
            visible: v.crumbsInline < v.crumbs.length
            width: 60; height: v.crumbH; leftCap: false; rightCap: false
            text: "…"; fam: v.fam; color: T.dim; ink: T.peach
        }
        Repeater {
            model: v.crumbs.slice(v.crumbs.length - v.crumbsInline)
            delegate: Pill {
                required property var modelData
                required property int index
                readonly property bool last: index === v.crumbsInline - 1
                width: last ? Math.max(130, v.width - 120 - (v.crumbsInline < v.crumbs.length ? 64 : 0) - (v.crumbsInline - 1) * 154 - (v.p.actionsInline ? 3 * 124 : 0) - T.gap * 2) : 150
                height: v.crumbH; px: 18; leftCap: false; rightCap: last && !v.p.actionsInline
                text: modelData; fam: v.fam
                color: last ? T.gold : (index % 2 ? T.lilac : T.peach)
            }
        }
        Repeater {
            model: v.p.actionsInline ? ["Up", "New folder", "Connect"] : []
            delegate: Pill {
                required property var modelData
                required property int index
                width: 120; height: v.crumbH; px: 18; leftCap: false; rightCap: index === 2
                text: modelData; fam: v.fam; color: index === 2 ? T.sunset : T.periwinkle
            }
        }
    }

    // ── Miller columns ──────────────────────────────────────────────
    Repeater {
        model: v.cols - 1
        delegate: Item {
            required property int index
            readonly property var items: index === v.cols - 2 ? Data.column2 : Data.column1
            readonly property string sel: index === v.cols - 2 ? "hensou" : "code"
            x: index * (v.sideColW + 10); y: v.colTop
            width: v.sideColW; height: v.colBottom - v.colTop
            Rectangle { width: parent.width; height: 8; color: T.lilac; topLeftRadius: 4 }
            Rectangle { y: 8; width: 8; height: parent.height - 8; color: T.lilac; bottomLeftRadius: 4 }
            Column {
                x: 16; y: 16; width: parent.width - 16; spacing: 2
                Repeater {
                    model: parent.parent.items
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 30
                        color: modelData.name === parent.parent.sel ? T.gold : "transparent"
                        Text {
                            x: 8; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: modelData.name === parent.parent.parent.sel ? T.space : T.lilac
                            font.family: v.fam; font.pixelSize: 20
                        }
                    }
                }
            }
        }
    }
    Item {
        id: current
        x: (v.cols - 1) * (v.sideColW + 10); y: v.colTop
        width: v.lastColW; height: v.colBottom - v.colTop
        Rectangle { width: parent.width; height: 8; color: T.sunset; topLeftRadius: 4; topRightRadius: 4 }
        Rectangle { y: 8; width: 8; height: parent.height - 8; color: T.sunset; bottomLeftRadius: 4 }
        FileList {
            x: 16; y: 14; width: parent.width - 16; height: parent.height - 14
            entries: v.entries; fam: v.fam; accent: T.sunset
            // The column reuses the same layout function on its own size.
            p: Plan.plan(width, v.height, 0)
        }
    }

    // ── Console strip: hosts and the transfer ───────────────────────
    Row {
        y: v.height - v.stripH; height: v.stripH; spacing: T.gap
        Repeater {
            model: v.hosts.slice(0, v.hostsInline)
            delegate: Pill {
                required property var modelData
                required property int index
                width: 140; height: v.stripH
                leftCap: index === 0; rightCap: false
                text: modelData.name; sub: modelData.detail; fam: v.fam
                active: index === 0
                color: modelData.detail === "Host key changed" || modelData.kind === "trash" ? T.alert
                     : modelData.kind === "ssh" ? T.periwinkle : T.sunset
            }
        }
        Pill {
            visible: v.hostsInline < v.hosts.length
            width: 106; height: v.stripH; leftCap: v.hostsInline === 0; rightCap: false
            text: v.hostsInline === 0 ? "Hosts" : "More (" + (v.hosts.length - v.hostsInline) + ")"
            fam: v.fam; color: T.peach
            onClicked: v.menuOpen = !v.menuOpen
        }
        Rectangle {
            width: Math.max(0, v.width - v.hostsInline * 144 - (v.hostsInline < v.hosts.length ? 110 : 0) - 224)
            height: v.stripH; color: T.dim
            Rectangle { width: parent.width * 0.62; height: parent.height; color: T.gold }
        }
        Pill {
            width: 220; height: v.stripH; leftCap: false; px: 18
            text: "Copying 3 items 62%"; sub: "aka to myoko"; fam: v.fam; color: T.gold
        }
    }

    HostMenu {
        visible: v.menuOpen
        items: v.hosts.slice(v.hostsInline)
        fam: v.fam
        width: Math.min(300, v.width - 16)
        x: Math.min(v.width - width - 8, v.hostsInline * 144)
        y: v.height - v.stripH - height - 8
    }
}
