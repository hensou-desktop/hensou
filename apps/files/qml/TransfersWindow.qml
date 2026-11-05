import QtQuick
import QtQuick.Layouts
import Hensou
import Hensou.Host
import "Model.js" as Model
import "LayoutPlan.js" as LayoutPlan

// Transfers and working copies, side by side when there is room and stacked
// when not; each list scrolls. Transfers belong to Files, not to a window:
// closing this window changes nothing. Every state has its own controls:
// progress and Stop, a conflict choice with Apply to all, waiting for a
// host, keep waiting or cancel after 10 minutes, and the end states.
Window {
    id: root
    required property var app
    readonly property bool win98: Theme.name === "win98"
    readonly property string theme: win98 ? "win98" : "platinum"
    readonly property real u: 2 / Math.max(0.5, metrics.devicePixelRatio)
    readonly property var plan: LayoutPlan.transfersPlan(width, height)
    property var dismissed: ({})
    // Per transfer: the conflict panel's Apply to all.
    property var applyAll: ({})

    readonly property var transfers: {
        const list = [];
        for (const id in app.store.transfers) if (!dismissed[id]) list.push(app.store.transfers[id]);
        list.sort(function(a, b) {
            const x = Model.transferActive(a) ? 0 : 1, y = Model.transferActive(b) ? 0 : 1;
            return x - y || b.id - a.id;
        });
        return list;
    }
    readonly property var copies: {
        const list = [];
        for (const k in app.store.copies) list.push(app.store.copies[k]);
        return list;
    }

    title: win98 ? "Transfers" : "Transfers"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: win98 ? Win98Tokens.face : PlatinumTokens.menuSurface
    width: 820
    height: 480
    minimumWidth: 220
    minimumHeight: 160

    function choose(transfer, choice) {
        app.store.send({ command: "resolve-conflict", id: transfer.id, choice: choice, apply_to_all: applyAll[String(transfer.id)] === true });
    }
    function dismiss(transfer) {
        const next = Object.assign({}, dismissed);
        next[String(transfer.id)] = true;
        dismissed = next;
    }
    function clearFinished() {
        const next = Object.assign({}, dismissed);
        for (const t of transfers) if (!Model.transferActive(t)) next[String(t.id)] = true;
        dismissed = next;
    }

    Shortcut { sequence: "Ctrl+W"; onActivated: root.close() }
    Shortcut { sequence: "Escape"; onActivated: root.close() }

    WindowScale {
        id: scale
        anchors.fill: parent
        devicePixelRatio: metrics.devicePixelRatio
        NativeWindowMetrics { id: metrics }

        // ---- chrome ----
        Loader {
            anchors.fill: parent
            sourceComponent: root.win98 ? memphisChrome : platinumChrome
        }
        Component {
            id: platinumChrome
            Item {
                Rectangle { anchors.fill: parent; color: PlatinumTokens.menuSurface; border.width: PlatinumTokens.hairFor(metrics.devicePixelRatio); border.color: PlatinumTokens.menuEdge }
                PlatinumTitleBar {
                    x: PlatinumTokens.hairFor(metrics.devicePixelRatio); y: x
                    width: parent.width - 2 * x
                    window: root
                    zoomable: false
                    collapsible: false
                    onCloseClicked: root.close()
                }
            }
        }
        Component {
            id: memphisChrome
            Item {
                Win98Bevel { anchors.fill: parent; variant: "window" }
                Rectangle {
                    x: 3 * root.u; y: 3 * root.u
                    width: parent.width - 6 * root.u
                    height: Win98Tokens.captionHeight * root.u
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.active ? Win98Tokens.caption1 : Win98Tokens.inactiveCaption1 }
                        GradientStop { position: 1; color: root.active ? Win98Tokens.caption2 : Win98Tokens.inactiveCaption2 }
                    }
                    MouseArea { anchors.fill: parent; onPressed: root.startSystemMove() }
                    Win98Text {
                        x: 3 * root.u; y: 3 * root.u
                        text: root.title
                        bold: true
                        accessMarks: false
                        color: root.active ? Win98Tokens.captionText : Win98Tokens.inactiveCaptionText
                    }
                    Win98CaptionButton {
                        x: parent.width - width - 2 * root.u
                        y: 2 * root.u
                        glyph: "close"
                        Accessible.name: "Close"
                        onClicked: root.close()
                    }
                }
            }
        }

        // ---- the two lists ----
        GridLayout {
            id: lists
            x: root.win98 ? 8 * root.u : 12
            y: root.win98 ? 26 * root.u : 32
            width: parent.width - 2 * x
            height: parent.height - y - (root.win98 ? 8 * root.u : 12)
            columns: root.plan.sideBySide ? 2 : 1
            columnSpacing: root.win98 ? 8 * root.u : 12
            rowSpacing: root.win98 ? 6 * root.u : 10

            Section {
                objectName: "transfersSection"
                title: "Transfers"
                empty: "No transfers. Copies and moves appear here while they run."
                count: root.transfers.length
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 3
                Layout.minimumHeight: 60
                action: root.transfers.some(function(t) { return !Model.transferActive(t); }) ? "Clear Finished" : ""
                onActionClicked: root.clearFinished()
                Repeater {
                    model: root.transfers
                    TransferRow { required property var modelData; transfer: modelData; width: parent ? parent.width : 0 }
                }
            }
            Section {
                objectName: "copiesSection"
                title: "Working Copies"
                empty: "No working copies. Remote files you open are listed here while Files watches them for saves."
                count: root.copies.length
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 2
                Layout.minimumHeight: 60
                Repeater {
                    model: root.copies
                    CopyRow { required property var modelData; copy: modelData; width: parent ? parent.width : 0 }
                }
            }
        }
        WindowEdges { anchors.fill: parent; window: root }
    }

    // A titled, scrolling list.
    component Section: Item {
        id: section
        property string title: ""
        property string empty: ""
        property int count: 0
        property string action: ""
        signal actionClicked()
        default property alias rows: column.data
        Accessible.role: Accessible.List
        Accessible.name: title
        FilesText { id: heading; x: 0; y: 0; text: section.title + (section.count ? " (" + section.count + ")" : ""); bold: true }
        FilesButton {
            visible: section.action !== ""
            anchors.right: parent.right
            y: Math.min(0, (heading.height - height) / 2)
            text: section.action
            onClicked: section.actionClicked()
        }
        Item {
            id: well
            y: heading.height + (root.win98 ? 8 * root.u : 10)
            width: parent.width
            height: parent.height - y
            Rectangle { anchors.fill: parent; visible: !root.win98; color: PlatinumTokens.list; border.width: PlatinumTokens.hairFor(metrics.devicePixelRatio); border.color: PlatinumTokens.bevelDark }
            Win98Bevel { anchors.fill: parent; visible: root.win98; variant: "field"; color: Win98Tokens.win }
            Flickable {
                id: flick
                x: root.win98 ? 2 * root.u : 1
                y: x
                width: parent.width - 2 * x - (bar.visible ? bar.width : 0)
                height: parent.height - 2 * y
                clip: true
                contentWidth: width
                contentHeight: column.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: column
                    width: flick.width
                }
            }
            FilesText {
                visible: section.count === 0
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 300)
                horizontalAlignment: Text.AlignHCenter
                wrap: true
                onWell: true
                disabledLook: true
                text: section.empty
            }
            Loader {
                id: bar
                anchors.right: parent.right
                y: root.win98 ? 2 * root.u : 1
                height: parent.height - 2 * y
                visible: flick.contentHeight > flick.height + 1
                width: visible ? (root.win98 ? Win98Tokens.scrollBar * root.u : PlatinumTokens.menuScrollBar - PlatinumTokens.hairFor(metrics.devicePixelRatio)) : 0
                sourceComponent: root.win98 ? win98Bar : platinumBar
                Component { id: platinumBar; PlatinumScrollBar { flickable: flick } }
                Component { id: win98Bar; Win98ScrollBar { flickable: flick } }
            }
        }
    }

    component Buttons: Flow {
        spacing: root.win98 ? 6 * root.u : 8
    }

    component TransferRow: Item {
        id: row
        required property var transfer
        readonly property string phase: transfer.state.state
        readonly property real pad: root.win98 ? 6 * root.u : 10
        objectName: "transfer-" + transfer.id
        implicitHeight: body.implicitHeight + 2 * pad + separator.height
        height: implicitHeight
        Accessible.role: Accessible.ListItem
        Accessible.name: Model.transferTitle(transfer, root.theme, root.app.hostname)
        ColumnLayout {
            id: body
            x: row.pad; y: row.pad
            width: row.width - 2 * row.pad
            spacing: root.win98 ? 4 * root.u : 6
            FilesText {
                Layout.fillWidth: true
                text: Model.transferTitle(row.transfer, root.theme, root.app.hostname)
                wrap: true
                onWell: true
            }
            FilesProgress {
                Layout.fillWidth: true
                visible: Model.transferActive(row.transfer) || row.phase === "done"
                value: Model.transferProgress(row.transfer)
            }
            FilesText {
                objectName: "transferDetail"
                Layout.fillWidth: true
                text: Model.transferDetail(row.transfer, root.theme)
                wrap: true
                small: true
                onWell: true
                color: row.phase === "failed" ? (root.win98 ? Win98Tokens.danger : PlatinumTokens.menuDanger) : "transparent"
            }
            // The conflict: both items, then the choice.
            ColumnLayout {
                visible: row.phase === "conflict"
                Layout.fillWidth: true
                spacing: root.win98 ? 4 * root.u : 6
                readonly property var conflict: row.phase === "conflict" ? row.transfer.state.conflict : null
                FilesText {
                    Layout.fillWidth: true
                    wrap: true
                    small: true
                    onWell: true
                    text: parent.conflict ? "Replace the existing item (" + Model.sizeInfo(parent.conflict.existing.size, root.theme) + ", modified " + Model.dateText(parent.conflict.existing.modified, root.theme, "column") + ")" : ""
                }
                FilesText {
                    Layout.fillWidth: true
                    wrap: true
                    small: true
                    onWell: true
                    text: parent.conflict ? "with this one (" + Model.sizeInfo(parent.conflict.source.size, root.theme) + ", modified " + Model.dateText(parent.conflict.source.modified, root.theme, "column") + ")?" : ""
                }
                FilesCheckBox {
                    objectName: "applyToAll"
                    visible: row.transfer.items_total === null || row.transfer.items_total === undefined || row.transfer.items_total - row.transfer.items_done > 1
                    text: "Apply to all"
                    checked: root.applyAll[String(row.transfer.id)] === true
                    onToggled: function(next) {
                        const all = Object.assign({}, root.applyAll);
                        all[String(row.transfer.id)] = next;
                        root.applyAll = all;
                    }
                }
                Buttons {
                    Layout.fillWidth: true
                    FilesButton { objectName: "conflict-replace"; text: "Replace"; roleLabels: ["Replace", "Skip", "Keep Both", "Stop"]; onClicked: root.choose(row.transfer, "replace") }
                    FilesButton { objectName: "conflict-skip"; text: "Skip"; roleLabels: ["Replace", "Skip", "Keep Both", "Stop"]; onClicked: root.choose(row.transfer, "skip") }
                    FilesButton { objectName: "conflict-keep-both"; text: "Keep Both"; roleLabels: ["Replace", "Skip", "Keep Both", "Stop"]; onClicked: root.choose(row.transfer, "keep-both") }
                    FilesButton { objectName: "conflict-stop"; text: "Stop"; isDefault: true; roleLabels: ["Replace", "Skip", "Keep Both", "Stop"]; onClicked: root.choose(row.transfer, "stop") }
                }
            }
            // After 10 minutes offline: keep waiting, or cancel.
            Buttons {
                visible: row.phase === "ask-keep-waiting"
                Layout.fillWidth: true
                FilesButton { objectName: "keep-waiting"; text: "Keep Waiting"; isDefault: true; onClicked: root.app.store.send({ command: "keep-waiting", id: row.transfer.id, keep: true }) }
                FilesButton { objectName: "stop-waiting"; text: "Cancel Transfer"; onClicked: root.app.store.send({ command: "keep-waiting", id: row.transfer.id, keep: false }) }
            }
            Buttons {
                visible: row.phase !== "ask-keep-waiting" && row.phase !== "conflict"
                Layout.fillWidth: true
                FilesButton {
                    objectName: "transfer-cancel"
                    visible: Model.transferActive(row.transfer)
                    text: root.win98 ? "Cancel" : "Stop"
                    onClicked: root.app.store.cancelTransfer(row.transfer.id)
                }
                FilesButton {
                    visible: !Model.transferActive(row.transfer)
                    text: "Remove"
                    onClicked: root.dismiss(row.transfer)
                }
            }
        }
        Rectangle {
            id: separator
            anchors.bottom: parent.bottom
            x: row.pad; width: row.width - 2 * row.pad
            height: root.win98 ? root.u : PlatinumTokens.hairFor(metrics.devicePixelRatio)
            color: root.win98 ? Win98Tokens.sh : PlatinumTokens.bevelDark
        }
    }

    component CopyRow: Item {
        id: copyRow
        required property var copy
        readonly property real pad: root.win98 ? 6 * root.u : 10
        readonly property string phase: copy.state.state
        implicitHeight: column.implicitHeight + 2 * pad + line.height
        height: implicitHeight
        Accessible.role: Accessible.ListItem
        Accessible.name: Model.basename(copy.remote.path)
        function resolve(choice) { root.app.store.send({ command: "resolve-remote-change", remote: copyRow.copy.remote, choice: choice }); }
        ColumnLayout {
            id: column
            x: copyRow.pad; y: copyRow.pad
            width: copyRow.width - 2 * copyRow.pad
            spacing: root.win98 ? 3 * root.u : 4
            FilesText {
                Layout.fillWidth: true
                wrap: true
                onWell: true
                text: Model.basename(copyRow.copy.remote.path) + " on " + Model.hostName(copyRow.copy.remote)
            }
            FilesText {
                Layout.fillWidth: true
                wrap: true
                small: true
                onWell: true
                disabledLook: true
                text: copyRow.copy.remote.path
            }
            FilesText {
                objectName: "copyState"
                Layout.fillWidth: true
                wrap: true
                small: true
                onWell: true
                color: copyRow.phase === "remote-changed" || copyRow.phase === "failed" ? (root.win98 ? Win98Tokens.warning : PlatinumTokens.menuWarning) : "transparent"
                text: Model.copyStateText(copyRow.copy) + (copyRow.copy.last_saved ? ". Last saved " + Model.dateText(copyRow.copy.last_saved, root.theme, "column") : "")
            }
            Buttons {
                Layout.fillWidth: true
                visible: copyRow.phase === "remote-changed"
                FilesButton { objectName: "remote-overwrite"; text: "Overwrite"; onClicked: copyRow.resolve("overwrite") }
                FilesButton { objectName: "remote-keep"; text: "Keep Remote"; onClicked: copyRow.resolve("keep-remote") }
                FilesButton { objectName: "remote-copy"; text: "Save As Copy"; isDefault: true; onClicked: copyRow.resolve("save-as-copy") }
            }
            Buttons {
                Layout.fillWidth: true
                FilesButton {
                    objectName: "stop-watching"
                    text: "Stop Watching"
                    onClicked: root.app.store.send({ command: "stop-watching", remote: copyRow.copy.remote })
                }
            }
        }
        Rectangle {
            id: line
            anchors.bottom: parent.bottom
            x: copyRow.pad; width: copyRow.width - 2 * copyRow.pad
            height: root.win98 ? root.u : PlatinumTokens.hairFor(metrics.devicePixelRatio)
            color: root.win98 ? Win98Tokens.sh : PlatinumTokens.bevelDark
        }
    }
}
