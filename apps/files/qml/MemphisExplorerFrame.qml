import QtQuick
import Hensou
import "Model.js" as Model
import "LayoutPlan.js" as LayoutPlan
import "Art.js" as Art

// A Windows 98 Explorer window: caption, menu bar, toolbar, address bar, the
// All Folders tree beside the listing, and the status bar. Rows yield by
// height (toolbar, then address, then status bar); their actions all live
// in the menus too. The tree yields by width; View > Folders and the Go
// menu keep its places reachable.
FocusScope {
    id: root
    required property var window
    readonly property real u: 2 / WindowMetrics.ratio(root)
    readonly property var plan: window.plan
    readonly property string theme: "win98"

    function focusAddress() { if (address.item) { addressField.takeFocus(); addressField.selectAll(); } }

    Win98Bevel { anchors.fill: parent; variant: "window" }

    // ---- caption ----
    Rectangle {
        id: caption
        objectName: "caption"
        x: 3 * root.u; y: 3 * root.u
        width: parent.width - 6 * root.u
        height: Win98Tokens.captionHeight * root.u
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.window.active ? Win98Tokens.caption1 : Win98Tokens.inactiveCaption1 }
            GradientStop { position: 1; color: root.window.active ? Win98Tokens.caption2 : Win98Tokens.inactiveCaption2 }
        }
        MouseArea {
            anchors.fill: parent
            onPressed: root.window.startSystemMove()
            onDoubleClicked: root.window.visibility === Window.Maximized ? root.window.showNormal() : root.window.showMaximized()
        }
        EntryIcon {
            x: 2 * root.u; y: root.u
            art: Model.artName(Model.placeEntry(root.window.location, "win98", ""))
            large: false
        }
        Win98Text {
            x: 21 * root.u
            y: 3 * root.u
            width: Math.max(0, Math.min(implicitWidth, buttons.x - 3 * root.u - x))
            text: root.window.title
            accessMarks: false
            bold: true
            color: root.window.active ? Win98Tokens.captionText : Win98Tokens.inactiveCaptionText
        }
        Row {
            id: buttons
            x: caption.width - 2 * root.u - width
            y: 2 * root.u
            spacing: 0
            Win98CaptionButton { glyph: "minimize"; onClicked: root.window.showMinimized(); Accessible.name: "Minimize" }
            Win98CaptionButton {
                glyph: root.window.visibility === Window.Maximized ? "restore" : "maximize"
                Accessible.name: "Maximize"
                onClicked: root.window.visibility === Window.Maximized ? root.window.showNormal() : root.window.showMaximized()
            }
            Item { width: 2 * root.u; height: 1 }
            Win98CaptionButton { objectName: "captionClose"; glyph: "close"; onClicked: root.window.close(); Accessible.name: "Close" }
        }
    }

    Column {
        id: chrome
        x: 3 * root.u
        y: caption.y + caption.height + root.u
        width: parent.width - 6 * root.u
        MenuRow {
            id: menuRow
            objectName: "menuRow"
            width: parent.width
            window: root.window
            menus: root.window.menus()
        }
        Win98Separator { width: parent.width; visible: toolbar.visible }
        // ---- toolbar ----
        Item {
            id: toolbar
            objectName: "toolbar"
            visible: root.plan.toolbar
            width: parent.width
            height: visible ? 40 * root.u : 0
            readonly property var tools: [
                { art: "tb-back", text: "Back", action: "back", enabled: root.window.historyIndex > 0 },
                { art: "tb-forward", text: "Forward", action: "forward", enabled: root.window.historyIndex < root.window.history.length - 1 },
                { art: "tb-up", text: "Up", action: "up", enabled: Model.parent(root.window.location) !== null },
                { art: "tb-cut", text: "Cut", action: "cut", enabled: root.window.deletable },
                { art: "tb-copy", text: "Copy", action: "copy", enabled: root.window.hasSelection },
                { art: "tb-paste", text: "Paste", action: "paste", enabled: root.window.canWrite },
                { art: "tb-delete", text: "Delete", action: "trash", enabled: root.window.deletable },
                { art: "tb-properties", text: "Properties", action: "info", enabled: true },
                { art: "tb-views", text: "Views", action: root.window.memory.view === "list" ? "view-icons" : "view-list", enabled: true }
            ]
            readonly property real toolWidth: 50 * root.u
            readonly property int inlineCount: LayoutPlan.fit(tools.map(function() { return toolbar.toolWidth; }), width - 4 * root.u, 16 * root.u)
            Row {
                x: 2 * root.u
                height: parent.height
                Repeater {
                    model: toolbar.tools.slice(0, toolbar.inlineCount)
                    Item {
                        id: tool
                        required property var modelData
                        objectName: "tool-" + modelData.action
                        width: toolbar.toolWidth
                        height: toolbar.height - 2 * root.u
                        y: root.u
                        enabled: modelData.enabled
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.text
                        Win98Bevel {
                            anchors.fill: parent
                            filled: false
                            visible: tool.enabled && toolArea.containsMouse
                            variant: toolArea.pressed ? "thinSunken" : "thinRaised"
                        }
                        Image {
                            x: Win98Tokens.snap((parent.width - width) / 2, root.u)
                            y: 3 * root.u
                            width: 20 * root.u; height: 20 * root.u
                            smooth: false
                            opacity: tool.enabled ? 1 : 0.4
                            sourceSize.width: Math.round(width * WindowMetrics.ratio(tool))
                            sourceSize.height: Math.round(height * WindowMetrics.ratio(tool))
                            source: Art.url("win98", tool.modelData.art, Win98Tokens.ink, "")
                        }
                        Win98Text {
                            x: Win98Tokens.snap((parent.width - width) / 2, root.u)
                            y: 25 * root.u
                            width: Math.min(implicitWidth, parent.width - 2 * root.u)
                            text: tool.modelData.text
                            accessMarks: false
                            disabledLook: !tool.enabled
                        }
                        MouseArea {
                            id: toolArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.window.act(tool.modelData.action)
                        }
                    }
                }
                Item {
                    id: chevron
                    objectName: "toolOverflow"
                    visible: toolbar.inlineCount < toolbar.tools.length
                    width: 16 * root.u
                    height: toolbar.height
                    Accessible.role: Accessible.Button
                    Accessible.name: "More tools"
                    Win98Bevel { anchors.fill: parent; anchors.margins: root.u; filled: false; variant: chevronArea.containsMouse ? "thinRaised" : "flat" }
                    Image {
                        anchors.centerIn: parent
                        width: 20 * root.u; height: 20 * root.u
                        sourceSize.width: Math.round(width * WindowMetrics.ratio(chevron))
                        sourceSize.height: Math.round(height * WindowMetrics.ratio(chevron))
                        source: Art.url("win98", "tb-more", Win98Tokens.ink, "")
                    }
                    MouseArea {
                        id: chevronArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const rest = toolbar.tools.slice(toolbar.inlineCount).map(function(t) { return { text: t.text, action: t.action, enabled: t.enabled }; });
                            const p = chevron.mapToItem(root.window.popupOverlay, 0, chevron.height);
                            root.window.popup(rest, p.x, p.y, "More tools");
                        }
                    }
                }
            }
        }
        Win98Separator { width: parent.width; visible: address.visible }
        // ---- address bar ----
        Item {
            id: address
            objectName: "addressBar"
            visible: root.plan.address
            width: parent.width
            height: visible ? 25 * root.u : 0
            Win98Text {
                id: addressLabel
                x: 4 * root.u
                y: 6 * root.u
                text: "A&ddress"
            }
            FilesField {
                id: addressField
                objectName: "addressField"
                x: addressLabel.x + addressLabel.width + 5 * root.u
                y: 2 * root.u
                width: parent.width - x - 2 * root.u
                height: Win98Tokens.fieldHeight * root.u
                accessibleName: "Address"
                text: Model.addressText(root.window.location, "win98", root.window.app.hostname)
                onAccepted: {
                    const next = Model.parseAddress(currentText, "win98", root.window.app.hostname);
                    if (next) { root.window.navigate(next); root.window.addressForced = false; }
                    else root.window.app.alert({ kind: "failure", art: "error", title: "Address", message: "Files cannot find " + currentText + ".",
                        detail: "Type a folder path (/home), a host and path (fuji:/srv) or a place (My Computer).",
                        buttons: [{ text: "OK", action: "ok" }], defaultAction: "ok", cancelAction: "ok" }, root.window, null);
                }
                onEscaped: {
                    root.window.addressForced = false;
                    if (item) item.text = Model.addressText(root.window.location, "win98", root.window.app.hostname);
                }
            }
        }
    }

    // ---- tree and listing ----
    Item {
        id: body
        x: 3 * root.u
        y: chrome.y + chrome.height + root.u
        width: parent.width - 6 * root.u
        height: Math.max(0, parent.height - y - 3 * root.u - (status.visible ? status.height + root.u : 0))

        Item {
            id: treePane
            objectName: "treePane"
            visible: root.plan.treeShown
            width: root.plan.treeWidth
            height: parent.height
            Win98Bevel {
                id: treeHeader
                width: parent.width
                height: 18 * root.u
                variant: "thinRaised"
                Win98Text { x: 4 * root.u; y: 3 * root.u; text: "All Folders"; accessMarks: false }
                Win98CaptionButton {
                    x: parent.width - width - 2 * root.u
                    y: 2 * root.u
                    glyph: "close"
                    Accessible.name: "Close All Folders"
                    onClicked: root.window.act("tree")
                }
            }
            FolderTree {
                objectName: "folderTree"
                y: treeHeader.height
                width: parent.width
                height: parent.height - y
                window: root.window
            }
        }
        FolderContent {
            id: content
            objectName: "folderContent"
            focus: true
            x: treePane.visible ? treePane.width + 3 * root.u : 0
            width: parent.width - x
            height: parent.height
            window: root.window
        }
        // "Reconnecting…": the listing stays, greyed, under this strip.
        Rectangle {
            objectName: "hostBanner"
            visible: root.window.banner.kind !== "none" && root.window.banner.kind !== "refused"
            x: content.x + 2 * root.u
            y: content.y + content.height - height - 2 * root.u
            width: Math.min(content.width - 4 * root.u, bannerText.implicitWidth + 30 * root.u)
            height: 20 * root.u
            color: Win98Tokens.tip
            border.width: root.u
            border.color: Win98Tokens.tipEdge
            Image {
                x: 3 * root.u; y: 2 * root.u
                width: 16 * root.u; height: 16 * root.u
                sourceSize.width: Math.round(width * WindowMetrics.ratio(parent))
                sourceSize.height: Math.round(height * WindowMetrics.ratio(parent))
                source: Art.url("win98", root.window.banner.kind === "failed" ? "error" : "network", Win98Tokens.ink, "")
            }
            Win98Text {
                id: bannerText
                x: 22 * root.u
                y: 4 * root.u
                width: Math.min(implicitWidth, parent.width - x - 4 * root.u)
                text: root.window.banner.text
                accessMarks: false
                color: Win98Tokens.tipText
            }
        }
    }

    // ---- status bar ----
    Item {
        id: status
        objectName: "statusBar"
        visible: root.plan.status
        x: 3 * root.u
        y: parent.height - height - 3 * root.u
        width: parent.width - 6 * root.u
        height: 18 * root.u
        readonly property var selected: root.window.selectedEntries
        readonly property var panes: {
            const n = root.window.entries.length;
            const hidden = root.window.memory.show_hidden ? 0 : root.window.hiddenCount;
            const what = selected.length > 0 ? selected.length + " object(s) selected"
                : n + " object(s)" + (hidden > 0 ? " (plus " + hidden + " hidden)" : "");
            const list = selected.length > 0 ? selected : root.window.entries;
            let bytes = 0, unknown = false, any = false;
            for (const e of list) {
                if (e.kind !== "file") continue;
                any = true;
                if (e.size === null || e.size === undefined) unknown = true; else bytes += e.size;
            }
            const size = !any ? "" : unknown ? "Unknown size" : Model.sizeInfo(bytes, "win98").replace(/ \(.*\)$/, "");
            const zone = Model.isRemote(root.window.location) ? root.window.location.place.name : "My Computer";
            return [what, size, zone];
        }
        readonly property real firstWidth: Math.round(width * 0.5)
        readonly property real restWidth: (width - firstWidth - 18 * root.u) / 2
        Row {
            spacing: 2 * root.u
            Repeater {
                model: status.panes
                Item {
                    required property string modelData
                    required property int index
                    width: index === 0 ? status.firstWidth : status.restWidth
                    height: status.height
                    Win98Bevel { anchors.fill: parent; filled: false; variant: "thinSunken" }
                    Win98Text {
                        x: 3 * root.u; y: 3 * root.u
                        width: parent.width - 6 * root.u
                        text: modelData
                        accessMarks: false
                    }
                }
            }
        }
        // The size grip.
        Item {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 12 * root.u; height: 12 * root.u
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: (index * 4 + 1) * root.u; y: (11 - index * 4 - 1) * root.u - 0
                    width: root.u; height: root.u
                    color: Win98Tokens.sh
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeFDiagCursor
                onPressed: root.window.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
            }
        }
    }
}
