import QtQuick
import Hensou
import "Model.js" as Model

// Explorer's All Folders tree: My Computer, Home, the volumes, Network
// Neighborhood (the SSH hosts) and the Recycle Bin, each folder expanding
// as it is listed. A click shows the folder in this window; a drop on a row
// moves or copies into it by the same rules as the listing.
FocusScope {
    id: root
    required property var window
    readonly property real u: 2 / WindowMetrics.ratio(root)
    readonly property var app: window.app
    readonly property var rows: Model.treeRows([Model.placeEntry(Model.computer(), "memphis", app.hostname)], window.treeExpanded,
        function(location) {
            const l = root.app.store.state.listings[Model.key(location)];
            return l && l.status !== "loading" ? l.entries : null;
        }, "memphis", app.hostname)
    readonly property real rowHeight: 18 * u
    activeFocusOnTab: true
    Accessible.role: Accessible.Tree
    Accessible.name: "All Folders"

    function indexOfCurrent() {
        for (let i = 0; i < rows.length; i++) if (rows[i].key === window.locationKey) return i;
        return -1;
    }
    Keys.onPressed: function(event) {
        const i = indexOfCurrent();
        if (event.key === Qt.Key_Down && i + 1 < rows.length) window.navigate(rows[i + 1].location);
        else if (event.key === Qt.Key_Up && i > 0) window.navigate(rows[i - 1].location);
        else if ((event.key === Qt.Key_Right || event.key === Qt.Key_Plus) && i >= 0 && !rows[i].expanded) window.toggleTree(rows[i].location);
        else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Minus) && i >= 0 && rows[i].expanded) window.toggleTree(rows[i].location);
        else return;
        event.accepted = true;
    }

    MemphisBevel { anchors.fill: parent; variant: "field"; color: MemphisTokens.win }
    ListView {
        id: list
        x: 2 * root.u; y: 2 * root.u
        width: parent.width - 4 * root.u - (bar.visible ? bar.width : 0)
        height: parent.height - 4 * root.u
        clip: true
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool current: modelData.key === root.window.locationKey
            width: list.width
            height: root.rowHeight
            Accessible.role: Accessible.TreeItem
            Accessible.name: modelData.name
            Accessible.selected: current
            Image {
                visible: row.modelData.expandable
                x: (row.modelData.depth * 19 + 3) * root.u
                y: MemphisTokens.snap((row.height - height) / 2, root.u)
                width: 9 * root.u; height: 9 * root.u
                smooth: false
                sourceSize.width: Math.round(width * WindowMetrics.ratio(row))
                sourceSize.height: Math.round(height * WindowMetrics.ratio(row))
                source: "data:image/svg+xml;utf8," + encodeURIComponent(row.modelData.expanded
                    ? '<svg xmlns="http://www.w3.org/2000/svg" width="9" height="9" viewBox="0 0 9 9" shape-rendering="crispEdges"><rect x="0.5" y="0.5" width="8" height="8" fill="' + MemphisTokens.win + '" stroke="' + MemphisTokens.gray + '"/><path d="M2 4.5 H7" stroke="' + MemphisTokens.winText + '"/></svg>'
                    : '<svg xmlns="http://www.w3.org/2000/svg" width="9" height="9" viewBox="0 0 9 9" shape-rendering="crispEdges"><rect x="0.5" y="0.5" width="8" height="8" fill="' + MemphisTokens.win + '" stroke="' + MemphisTokens.gray + '"/><path d="M2 4.5 H7 M4.5 2 V7" stroke="' + MemphisTokens.winText + '"/></svg>')
                MouseArea { anchors.fill: parent; anchors.margins: -3 * root.u; onClicked: root.window.toggleTree(row.modelData.location) }
            }
            EntryIcon {
                id: icon
                x: (row.modelData.depth * 19 + 15) * root.u
                y: root.u
                art: row.modelData.art
                large: false
                selected: row.current || root.window.dropTargetKey === "tree:" + row.modelData.key
            }
            Rectangle {
                x: icon.x + icon.width + 3 * root.u
                y: root.u
                width: Math.min(label.implicitWidth + 4 * root.u, row.width - x)
                height: 16 * root.u
                color: row.current ? MemphisTokens.selection : "transparent"
                MemphisText {
                    id: label
                    x: 2 * root.u; y: 2 * root.u
                    width: Math.min(implicitWidth, parent.width - 4 * root.u)
                    text: row.modelData.name
                    accessMarks: false
                    color: row.current ? MemphisTokens.selectionText : MemphisTokens.winText
                }
                MemphisFocusRect {
                    visible: row.current && root.activeFocus
                    anchors.fill: parent
                    color: MemphisTokens.selectionText
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.forceActiveFocus(); root.window.navigate(row.modelData.location); }
                    onDoubleClicked: root.window.toggleTree(row.modelData.location)
                }
            }
            DropArea {
                anchors.fill: parent
                onEntered: function(drag) { root.window.dropTargetKey = "tree:" + row.modelData.key; drag.accept(Qt.CopyAction); }
                onExited: if (root.window.dropTargetKey === "tree:" + row.modelData.key) root.window.dropTargetKey = ""
                onDropped: function(drop) {
                    root.window.dropTargetKey = "";
                    const p = row.mapToItem(root.window.popupOverlay, drop.x, drop.y);
                    const action = root.window.dropInto(row.modelData.location, drop, p.x, p.y);
                    if (action === Qt.IgnoreAction) drop.accepted = false;
                    else drop.accept(action);
                }
            }
        }
    }
    MemphisScrollBar {
        id: bar
        visible: list.contentHeight > list.height + 1
        x: parent.width - width - 2 * root.u
        y: 2 * root.u
        height: parent.height - 4 * root.u
        flickable: list
        step: root.rowHeight
    }
}
