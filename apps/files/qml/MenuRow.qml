import QtQuick
import Hensou
import "LayoutPlan.js" as LayoutPlan

// The menu row inside a window (there is no global menu bar). Titles that do
// not fit move whole, from the end, into an overflow title whose menu holds
// their entries under their names. F10 opens the first title; Left and
// Right move between titles while a menu is open.
Item {
    id: root
    required property var window
    property var menus: []          // [{ id, title, entries }]
    property int openIndex: -1
    readonly property bool win98: Theme.name === "win98"
    readonly property real u: 2 / WindowMetrics.ratio(root)
    readonly property real pad: win98 ? 6 * u : 10
    readonly property var widths: menus.map(function(m) { return root.titleWidth(m.title); })
    readonly property real overflowWidth: titleWidth("\u00bb")
    readonly property int inlineCount: LayoutPlan.fit(widths, width, overflowWidth)
    readonly property var overflowEntries: {
        const out = [];
        for (let i = inlineCount; i < menus.length; i++) {
            out.push({ text: menus[i].title, header: true });
            for (const e of menus[i].entries) out.push(e);
        }
        return out;
    }
    implicitHeight: win98 ? 18 * u : 22

    function titleWidth(text) {
        return win98 ? Math.ceil(Win98Tokens.textWidth(text, false, u) / u) * u + 12 * u
            : PlatinumMetrics.width(text) + 2 * pad;
    }
    // index === menus.length (or more) is the overflow title.
    function open(index) {
        const count = inlineCount < menus.length ? inlineCount + 1 : menus.length;
        if (count === 0) return;
        const i = (index + count) % count;
        const title = repeater.itemAt(i);
        const overflow = i >= inlineCount;
        popupMenu.entries = overflow ? overflowEntries : menus[i].entries;
        popupMenu.name = overflow ? "More menus" : menus[i].title;
        openIndex = i;
        popupMenu.openBelow(overflow ? overflowTitle : title);
    }
    function closeMenus() { popupMenu.close(); }

    Rectangle {
        anchors.fill: parent
        color: root.win98 ? Win98Tokens.face : PlatinumTokens.menuSurface
    }
    Rectangle {
        visible: !root.win98
        anchors.bottom: parent.bottom
        width: parent.width
        height: PlatinumTokens.hairFor(WindowMetrics.ratio(root))
        color: PlatinumTokens.bevelDark
    }

    component Title: Item {
        id: title
        property string text: ""
        property bool isOpen: false
        property int titleIndex: 0
        width: root.titleWidth(text)
        height: root.height
        Accessible.role: Accessible.MenuItem
        Accessible.name: text
        Rectangle {
            visible: !root.win98 && title.isOpen
            anchors.fill: parent
            color: PlatinumTokens.highlight
        }
        Win98Bevel {
            visible: root.win98 && (title.isOpen || area.containsMouse)
            y: root.u
            width: parent.width
            height: parent.height - 2 * root.u
            filled: false
            variant: title.isOpen ? "thinSunken" : "thinRaised"
        }
        FilesText {
            x: root.pad + (root.win98 && title.isOpen ? root.u : 0)
            y: root.win98 ? 3 * root.u + (title.isOpen ? root.u : 0) : (parent.height - height) / 2
            text: title.text
            color: !root.win98 && title.isOpen ? PlatinumTokens.highlightText : "transparent"
            small: false
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (root.openIndex >= 0 && root.openIndex !== title.titleIndex) root.open(title.titleIndex)
            onPressed: if (root.openIndex === title.titleIndex) root.closeMenus(); else root.open(title.titleIndex)
        }
    }

    Row {
        id: titles
        height: parent.height
        Repeater {
            id: repeater
            model: root.menus.slice(0, root.inlineCount)
            Title {
                required property var modelData
                required property int index
                objectName: "menuTitle-" + modelData.id
                text: modelData.title
                isOpen: root.openIndex === index
                titleIndex: index
            }
        }
        Title {
            id: overflowTitle
            objectName: "menuTitle-overflow"
            visible: root.inlineCount < root.menus.length
            text: "\u00bb"
            isOpen: root.openIndex === root.inlineCount
            titleIndex: root.inlineCount
            Accessible.name: "More menus"
        }
    }

    FilesMenu {
        id: popupMenu
        objectName: "menuRowMenu"
        owner: root.window
        onChosen: function(action, data) { root.window.act(action, data); }
        onClosed: root.openIndex = -1
        onStepped: function(direction) { Qt.callLater(function() { root.open(root.lastIndex + direction); }); }
        property int lastIndex: 0
        onOpened: lastIndex = root.openIndex
    }
}
