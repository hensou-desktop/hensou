import QtQuick
import Hensou
import "Model.js" as Model

// A Mac OS 8 Finder window: the striped title bar, the menu row (inside the
// window, as there is no global menu bar), the header with the item count,
// the folder's items, and the grow box. A host that is down keeps its last
// listing, greyed, under a "Reconnecting…" strip.
FocusScope {
    id: root
    required property var window
    readonly property real hair: PlatinumTokens.hairFor(WindowMetrics.ratio(root))
    property real shadedHeight: 0

    function focusAddress() {}
    function toggleCollapse() {
        if (shadedHeight > 0) {
            window.minimumHeight = 120;
            window.height = shadedHeight;
            shadedHeight = 0;
        } else {
            shadedHeight = window.height;
            window.minimumHeight = 0;
            window.height = titleBar.height + 2 * hair;
        }
    }
    Component.onDestruction: if (shadedHeight > 0) window.height = shadedHeight

    Rectangle {
        anchors.fill: parent
        color: PlatinumTokens.menuSurface
        border.width: root.hair
        border.color: PlatinumTokens.menuEdge
    }

    Column {
        id: chrome
        x: root.hair
        y: root.hair
        width: parent.width - 2 * root.hair
        PlatinumTitleBar {
            id: titleBar
            width: parent.width
            window: root.window
            onCloseClicked: root.window.close()
            onZoomClicked: root.window.visibility === Window.Maximized ? root.window.showNormal() : root.window.showMaximized()
            onCollapseClicked: root.toggleCollapse()
        }
        MenuRow {
            id: menuRow
            objectName: "menuRow"
            width: parent.width
            visible: root.shadedHeight === 0
            window: root.window
            menus: root.window.menus()
        }
        // The header: what the window holds, and what it is doing.
        Item {
            id: header
            width: parent.width
            visible: root.shadedHeight === 0 && (root.window.plan.status || banner.visible)
            height: visible ? 20 : 0
            Rectangle { anchors.fill: parent; color: PlatinumTokens.menuSurface }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: root.hair; color: PlatinumTokens.bevelDark }
            FilesText {
                id: count
                objectName: "itemCount"
                visible: !banner.visible
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 16)
                small: true
                text: {
                    const n = root.window.entries.length;
                    const hidden = root.window.memory.show_hidden ? 0 : root.window.hiddenCount;
                    const base = n === 1 ? "1 item" : n + " items";
                    return hidden > 0 ? base + ", " + hidden + " hidden" : base;
                }
            }
            Row {
                id: banner
                objectName: "hostBanner"
                visible: root.window.banner.kind !== "none"
                anchors.centerIn: parent
                spacing: 6
                PlatinumIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.window.banner.kind === "refused" ? "lock" : "cloud"
                    size: 12
                    color: root.window.banner.kind === "refused" ? PlatinumTokens.menuDanger : PlatinumTokens.menuText
                }
                FilesText {
                    anchors.verticalCenter: parent.verticalCenter
                    small: true
                    text: root.window.banner.text
                    color: root.window.banner.kind === "refused" || root.window.banner.kind === "failed" ? PlatinumTokens.menuDanger : "transparent"
                }
            }
        }
    }

    FolderContent {
        id: content
        objectName: "folderContent"
        focus: true
        visible: root.shadedHeight === 0
        x: root.hair
        y: chrome.y + chrome.height
        width: parent.width - 2 * root.hair
        height: Math.max(0, parent.height - y - root.hair)
        window: root.window
    }

    // The grow box: drag to resize, as a Mac OS window does.
    PlatinumBevel {
        id: grow
        objectName: "growBox"
        visible: root.shadedHeight === 0
        width: 15
        height: 15
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.hair
        color: PlatinumTokens.raised
        Repeater {
            model: 2
            Rectangle {
                required property int index
                x: 4 + index * 3; y: 4 + index * 3
                width: 7 - index * 3; height: 7 - index * 3
                color: "transparent"
                border.width: root.hair
                border.color: PlatinumTokens.bevelDark
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeFDiagCursor
            onPressed: root.window.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
        }
        Accessible.role: Accessible.Grip
        Accessible.name: "Resize"
    }
}
