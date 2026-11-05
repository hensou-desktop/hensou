import QtQuick
import Hensou
import Hensou.Files
import "Model.js" as Model
import "LayoutPlan.js" as LayoutPlan

// A folder's items as icons or as a list, in the current theme. The window
// owns the data and selection; this view draws them and reports gestures.
// Every state is drawn: opening, empty, error, refused, reconnecting
// (greyed, last listing kept) and ready.
FocusScope {
    id: root
    required property var window
    readonly property bool win98: Theme.name === "win98"
    readonly property string theme: win98 ? "win98" : "platinum"
    readonly property real u: 2 / WindowMetrics.ratio(root)
    readonly property bool listMode: window.memory.view === "list"
    readonly property var entries: window.entries
    readonly property var listing: window.listing
    readonly property string status: listing ? listing.status : "loading"
    readonly property bool refused: window.banner.kind === "refused"
    readonly property bool showsItems: !refused && entries.length > 0 && (status === "ready" || status === "refreshing" || window.greyed || status === "error")
    readonly property var columns: {
        const shown = window.plan.columns;
        const order = win98 ? ["size", "kind", "modified"] : ["modified", "size", "kind"];
        return order.filter(function(c) { return shown.indexOf(c) >= 0; });
    }
    readonly property var columnWidths: ({ modified: win98 ? 120 * u : 170, size: win98 ? 64 * u : 80, kind: win98 ? 100 * u : 130 })
    readonly property real rowHeight: win98 ? 18 * u : 20
    readonly property real columnsWidth: columns.reduce(function(sum, c) { return sum + columnWidths[c]; }, 0)
    readonly property Flickable flick: viewLoader.item ? viewLoader.item.flick : null
    property bool dragActive: false
    readonly property real barWidth: win98 ? Win98Tokens.scrollBar * u : PlatinumTokens.menuScrollBar - PlatinumTokens.hairFor(WindowMetrics.ratio(root))
    activeFocusOnTab: true
    Accessible.role: Accessible.List
    Accessible.name: window.title

    function columnTitle(c) {
        if (c === "modified") return win98 ? "Modified" : "Date Modified";
        if (c === "size") return "Size";
        if (c === "kind") return win98 ? "Type" : "Kind";
        return win98 ? "Name" : "Name";
    }
    function columnValue(c, entry) {
        if (c === "modified") return Model.dateText(entry.modified, theme, "column");
        if (c === "size") return Model.sizeText(entry.size, theme, entry);
        return Model.kindText(entry, theme);
    }
    function isCut(entry) { return window.app.cutKeys[Model.key(entry.location)] === true; }
    function entryAt(x, y) {
        if (!viewLoader.item) return null;
        const view = viewLoader.item.flick;
        const p = root.mapToItem(view.contentItem, x, y);
        const index = view.indexAt(p.x, p.y);
        return index >= 0 && index < entries.length ? entries[index] : null;
    }
    function reveal() {
        if (!viewLoader.item) return;
        const i = window.indexOfKey(window.currentKey);
        if (i >= 0) viewLoader.item.flick.positionViewAtIndex(i, listMode ? ListView.Contain : GridView.Contain);
    }
    function perRow() { return listMode || !viewLoader.item ? 1 : Math.max(1, Math.floor(viewLoader.item.flick.width / viewLoader.item.flick.cellWidth)); }

    Keys.onPressed: function(event) {
        const extend = (event.modifiers & Qt.ShiftModifier) !== 0;
        if (event.key === Qt.Key_Down && !(event.modifiers & Qt.ControlModifier)) window.moveCurrent(perRow(), extend);
        else if (event.key === Qt.Key_Up && !(event.modifiers & Qt.ControlModifier)) window.moveCurrent(-perRow(), extend);
        else if (event.key === Qt.Key_Right && !listMode) window.moveCurrent(1, extend);
        else if (event.key === Qt.Key_Left && !listMode) window.moveCurrent(-1, extend);
        else if (event.key === Qt.Key_Home) window.moveCurrent(-entries.length, extend);
        else if (event.key === Qt.Key_End) window.moveCurrent(entries.length, extend);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // Memphis opens; the Finder's Return names the item (Get Info).
            if (win98 || (event.modifiers & Qt.ControlModifier)) window.openSelection(event.modifiers & Qt.AltModifier ? Model.ALT : 0);
            else window.act("rename");
        }
        else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && extend)) {
            const e = window.currentEntry;
            window.contextMenu(e, root.width / 3, root.height / 3);
        }
        else return;
        event.accepted = true;
        reveal();
    }

    // The well.
    Rectangle {
        anchors.fill: parent
        visible: !root.win98
        color: PlatinumTokens.list
    }
    Win98Bevel {
        anchors.fill: parent
        visible: root.win98
        variant: "field"
        color: Win98Tokens.win
    }

    Item {
        id: viewport
        anchors.fill: parent
        anchors.margins: root.win98 ? 2 * root.u : 0
        clip: true
        opacity: root.window.greyed ? 0.45 : 1

        // Background gestures: click clears, right/Ctrl click opens the
        // folder's menu.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(mouse) {
                root.forceActiveFocus();
                const contextual = mouse.button === Qt.RightButton || (!root.win98 && (mouse.modifiers & Qt.ControlModifier));
                if (contextual) {
                    const p = mapToItem(root.window.popupOverlay, mouse.x, mouse.y);
                    root.window.contextMenu(null, p.x, p.y);
                } else root.window.clearSelection();
            }
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            visible: root.showsItems
            sourceComponent: root.listMode ? listView : iconView
        }
    }

    // ---- states that are not a listing ----
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 360)
        spacing: 10
        visible: !root.showsItems
        FilesText {
            objectName: "contentState"
            width: parent.width
            wrap: true
            onWell: true
            horizontalAlignment: Text.AlignHCenter
            disabledLook: root.status !== "error" && !root.refused
            color: root.win98 ? "transparent" : PlatinumTokens.menuText
            text: root.refused ? root.window.banner.text
                : root.status === "error" ? Model.errorText(root.listing.error)
                : root.status === "loading" || root.status === "refreshing" ? (Model.isRemote(root.window.location) ? "Connecting\u2026" : "Opening\u2026")
                : "This folder is empty."
        }
        FilesButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.status === "error" || root.refused
            text: "Try Again"
            onClicked: root.window.reconnect()
        }
    }

    // ---- drops ----
    DropArea {
        anchors.fill: parent
        keys: []
        onEntered: function(drag) {
            root.dragActive = true;
            drag.accept(Qt.CopyAction);
        }
        onPositionChanged: function(drag) {
            const e = root.entryAt(drag.x, drag.y);
            root.window.dropTargetKey = e && Model.isContainer(e) ? Model.key(e.location) : "";
        }
        onExited: { root.dragActive = false; root.window.dropTargetKey = ""; }
        onDropped: function(drop) {
            root.dragActive = false;
            root.window.dropTargetKey = "";
            const e = root.entryAt(drop.x, drop.y);
            const target = e && Model.isContainer(e) ? Model.openTarget(e) : root.window.location;
            const p = root.mapToItem(root.window.popupOverlay, drop.x, drop.y);
            const action = root.window.dropInto(target, drop, p.x, p.y);
            if (action === Qt.IgnoreAction) drop.accepted = false;
            else drop.accept(action);
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.dragActive && root.window.dropTargetKey === ""
        color: "transparent"
        border.width: root.win98 ? 2 * root.u : 2
        border.color: root.win98 ? Win98Tokens.selection : PlatinumTokens.focusRing
    }
    // Keyboard focus, Platinum style (the lavender ring inside the well).
    Rectangle {
        anchors.fill: parent
        visible: !root.win98 && root.activeFocus
        color: "transparent"
        border.width: PlatinumTokens.focusRingFor(WindowMetrics.ratio(root))
        border.color: PlatinumTokens.focusRing
    }

    // ---- shared item gestures ----
    component Gestures: MouseArea {
        id: gestures
        required property var entry
        property point pressPoint
        property int pressButton: Qt.LeftButton
        property bool dragging: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: function(mouse) {
            root.forceActiveFocus();
            pressPoint = Qt.point(mouse.x, mouse.y);
            pressButton = mouse.button;
            dragging = false;
            const contextual = mouse.button === Qt.RightButton || (!root.win98 && (mouse.modifiers & Qt.ControlModifier));
            if (contextual && !(root.win98 && mouse.button === Qt.RightButton)) {
                const p = mapToItem(root.window.popupOverlay, mouse.x, mouse.y);
                root.window.contextMenu(entry, p.x, p.y);
                return;
            }
            root.window.pressSelect(entry, mouse.modifiers);
        }
        onPositionChanged: function(mouse) {
            if (!pressed || dragging) return;
            if (Math.abs(mouse.x - pressPoint.x) + Math.abs(mouse.y - pressPoint.y) < 6) return;
            dragging = true;
            // Memphis right-drag ends in a Move/Copy menu.
            root.window.beginDrag(gestures, pressButton === Qt.RightButton ? "right" : "left");
            // The native drag swallowed the release; reset the press.
            enabled = false;
            enabled = true;
        }
        onReleased: function(mouse) {
            if (dragging) { dragging = false; return; }
            if (root.win98 && mouse.button === Qt.RightButton) {
                const p = mapToItem(root.window.popupOverlay, mouse.x, mouse.y);
                root.window.contextMenu(entry, p.x, p.y);
            } else if (mouse.button === Qt.LeftButton && !(mouse.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))
                       && root.window.selectedEntries.length > 1) {
                root.window.select(entry, 0);
            }
        }
        onDoubleClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.window.activate(entry, mouse.modifiers);
        }
    }

    // ---- icons ----
    Component {
        id: iconView
        Item {
            readonly property alias flick: grid
            GridView {
                id: grid
                objectName: "iconGrid"
                anchors.fill: parent
                anchors.rightMargin: bar.visible ? bar.width : 0
                clip: true
                model: root.entries
                cellWidth: root.win98 ? 76 * root.u : 96
                cellHeight: root.win98 ? 70 * root.u : 80
                boundsBehavior: Flickable.StopAtBounds
                topMargin: root.win98 ? 4 * root.u : 8
                currentIndex: root.window.indexOfKey(root.window.currentKey)
                highlightFollowsCurrentItem: false
                keyNavigationEnabled: false
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property string itemKey: Model.key(modelData.location)
                    readonly property bool selected: root.window.selection[itemKey] === true
                    readonly property bool target: root.window.dropTargetKey === itemKey
                    readonly property bool alias: modelData.kind === "alias"
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Accessible.role: Accessible.ListItem
                    Accessible.name: Model.entryName(modelData, root.theme)
                    Accessible.selected: selected
                    EntryIcon {
                        id: icon
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.win98 ? 2 * root.u : 2
                        art: modelData.kind === "trash" && root.window.app.store.state.trash.length > 0 ? "trash-full" : Model.artName(modelData)
                        large: true
                        alias: cell.alias
                        selected: cell.selected || cell.target
                        dim: root.isCut(modelData) || modelData.hidden
                    }
                    Rectangle {
                        id: nameBox
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: icon.y + icon.height + (root.win98 ? 3 * root.u : 4)
                        width: Math.min(parent.width - 6, label.implicitWidth + (root.win98 ? 4 * root.u : 6))
                        height: label.height + (root.win98 ? 2 * root.u : 2)
                        color: cell.selected ? (root.win98 ? Win98Tokens.selection : (Theme.dark ? PlatinumTokens.highlight : "#000000")) : "transparent"
                        FilesText {
                            id: label
                            anchors.centerIn: parent
                            // Measured, plus a unit, so a short name never wraps.
                            width: Math.min(root.win98 ? Win98Tokens.ceilU(Win98Tokens.textWidth(text, false, root.u), root.u) + root.u
                                : PlatinumMetrics.smallWidth(text) + (cell.alias ? 4 : 2), cell.width - 10)
                            text: Model.entryName(modelData, root.theme)
                            wrap: true
                            maximumLineCount: cell.selected ? 4 : 2
                            italic: cell.alias
                            small: !root.win98
                            onWell: true
                            horizontalAlignment: Text.AlignHCenter
                            color: cell.selected ? (root.win98 ? Win98Tokens.selectionText : "#ffffff") : "transparent"
                        }
                        Win98FocusRect {
                            visible: root.win98 && root.activeFocus && root.window.currentKey === cell.itemKey
                            anchors.fill: parent
                            color: cell.selected ? Win98Tokens.selectionText : Win98Tokens.winText
                        }
                    }
                    Gestures {
                        entry: modelData
                        x: Math.min(icon.x, nameBox.x)
                        width: Math.max(icon.width, nameBox.width)
                        height: nameBox.y + nameBox.height
                    }
                }
            }
            Loader {
                id: bar
                anchors.right: parent.right
                height: parent.height
                visible: grid.contentHeight > grid.height + 1
                width: visible ? root.barWidth : 0
                sourceComponent: root.win98 ? win98Bar : platinumBar
                Component { id: platinumBar; PlatinumScrollBar { flickable: grid } }
                Component { id: win98Bar; Win98ScrollBar { flickable: grid; step: grid.cellHeight } }
            }
        }
    }

    // ---- list ----
    Component {
        id: listView
        Item {
            readonly property alias flick: list
            Item {
                id: header
                width: parent.width
                height: root.win98 ? 18 * root.u : 20
                Rectangle {
                    anchors.fill: parent
                    visible: !root.win98
                    color: PlatinumTokens.menuSurface
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: PlatinumTokens.hairFor(WindowMetrics.ratio(parent)); color: PlatinumTokens.bevelDark }
                }
                Row {
                    anchors.fill: parent
                    Repeater {
                        model: ["name"].concat(root.columns)
                        Item {
                            required property string modelData
                            readonly property bool sorted: root.window.memory.sort_column === modelData
                            width: modelData === "name" ? header.width - root.columnsWidth - (barList.visible ? barList.width : 0)
                                : root.columnWidths[modelData]
                            height: header.height
                            Accessible.role: Accessible.ColumnHeader
                            Accessible.name: root.columnTitle(modelData)
                            Win98Bevel {
                                visible: root.win98
                                anchors.fill: parent
                                variant: headArea.pressed ? "thinSunken" : "button"
                            }
                            FilesText {
                                x: root.win98 ? 5 * root.u : 8
                                y: root.win98 ? 3 * root.u : (parent.height - height) / 2
                                width: parent.width - 2 * x
                                text: root.columnTitle(modelData)
                                small: !root.win98
                                bold: false
                                color: !root.win98 && parent.sorted ? PlatinumTokens.highlight : "transparent"
                            }
                            Rectangle {
                                visible: !root.win98 && parent.sorted
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                x: 6; width: parent.width - 12; height: 2
                                color: PlatinumTokens.highlight
                            }
                            MouseArea {
                                id: headArea
                                anchors.fill: parent
                                onClicked: root.window.sortBy(modelData)
                            }
                        }
                    }
                }
            }
            ListView {
                id: list
                objectName: "detailList"
                y: header.height
                width: parent.width - (barList.visible ? barList.width : 0)
                height: parent.height - header.height
                clip: true
                model: root.entries
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.window.indexOfKey(root.window.currentKey)
                highlightFollowsCurrentItem: false
                keyNavigationEnabled: false
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property string itemKey: Model.key(modelData.location)
                    readonly property bool selected: root.window.selection[itemKey] === true
                    readonly property bool target: root.window.dropTargetKey === itemKey
                    readonly property color ink: selected ? (root.win98 ? Win98Tokens.selectionText : PlatinumTokens.highlightText) : "transparent"
                    width: list.width
                    height: root.rowHeight
                    Accessible.role: Accessible.ListItem
                    Accessible.name: Model.entryName(modelData, root.theme)
                    Accessible.selected: selected
                    Rectangle {
                        visible: !root.win98 && (row.selected || row.target)
                        anchors.fill: parent
                        color: PlatinumTokens.highlight
                    }
                    EntryIcon {
                        id: small
                        x: root.win98 ? 2 * root.u : 6
                        anchors.verticalCenter: parent.verticalCenter
                        art: modelData.kind === "trash" && root.window.app.store.state.trash.length > 0 ? "trash-full" : Model.artName(modelData)
                        large: false
                        alias: modelData.kind === "alias"
                        selected: root.win98 && (row.selected || row.target)
                        dim: root.isCut(modelData) || modelData.hidden
                    }
                    Rectangle {
                        id: nameCell
                        x: small.x + small.width + (root.win98 ? 3 * root.u : 6)
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property string name: Model.entryName(modelData, root.theme)
                        readonly property real pad: root.win98 ? 2 * root.u : 0
                        // The room left of the detail columns, and the name's own width.
                        readonly property real room: list.width - root.columnsWidth - x - (root.win98 ? 4 * root.u : 8)
                        readonly property real natural: root.win98 ? Win98Tokens.ceilU(Win98Tokens.textWidth(name, false, root.u), root.u)
                            : PlatinumMetrics.smallWidth(name) + (modelData.kind === "alias" ? 4 : 0)
                        width: Math.max(0, Math.min(natural + 2 * pad + (root.win98 ? root.u : 2), room))
                        height: root.win98 ? 14 * root.u : root.rowHeight - 4
                        color: root.win98 && (row.selected || row.target) ? Win98Tokens.selection : "transparent"
                        FilesText {
                            id: nameText
                            x: nameCell.pad
                            y: root.win98 ? root.u : (nameCell.height - height) / 2
                            width: nameCell.width - 2 * nameCell.pad
                            text: nameCell.name
                            italic: modelData.kind === "alias"
                            small: !root.win98
                            onWell: true
                            color: row.ink
                        }
                        Win98FocusRect {
                            visible: root.win98 && root.activeFocus && root.window.currentKey === row.itemKey
                            anchors.fill: parent
                            color: row.selected ? Win98Tokens.selectionText : Win98Tokens.winText
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        height: parent.height
                        Repeater {
                            model: root.columns
                            Item {
                                required property string modelData
                                width: root.columnWidths[modelData]
                                height: row.height
                                FilesText {
                                    x: root.win98 ? 6 * root.u : 10
                                    width: parent.width - 2 * x
                                    y: (row.height - height) / 2
                                    text: root.columnValue(parent.modelData, row.modelData)
                                    small: !root.win98
                                    onWell: true
                                    horizontalAlignment: parent.modelData === "size" ? Text.AlignRight : Text.AlignLeft
                                    color: row.selected && !root.win98 ? PlatinumTokens.highlightText : "transparent"
                                }
                            }
                        }
                    }
                    Gestures {
                        entry: modelData
                        anchors.fill: parent
                    }
                }
            }
            Loader {
                id: barList
                anchors.right: parent.right
                y: header.height
                height: parent.height - header.height
                visible: list.contentHeight > list.height + 1
                width: visible ? root.barWidth : 0
                sourceComponent: root.win98 ? win98ListBar : platinumListBar
                Component { id: platinumListBar; PlatinumScrollBar { flickable: list } }
                Component { id: win98ListBar; Win98ScrollBar { flickable: list; step: root.rowHeight } }
            }
        }
    }
}
