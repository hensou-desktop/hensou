import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Hensou
import Hensou.Host

// A pull-down, context or overflow menu: a native popup window that escapes
// its owner (intrinsic rule 8). Entries: { text, action, enabled, checked,
// separator, header, shortcut, bold, data }. Disabled entries stay visible.
Popup {
    id: root
    required property var owner
    property var entries: []
    property int highlighted: -1
    property string name: ""
    signal chosen(string action, var data)
    signal dismissed()
    // Left or Right in a menu bar's menu: open the neighbouring title.
    signal stepped(int direction)
    popupType: Popup.Window
    padding: 0
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: owner.popupOverlay
    implicitWidth: surface.implicitWidth
    implicitHeight: surface.implicitHeight
    background: Item {}
    readonly property bool win98: Theme.name === "win98"

    function usable(i) {
        const e = entries[i];
        return e && !e.separator && !e.header && e.enabled !== false;
    }
    function first() {
        for (let i = 0; i < entries.length; i++) if (usable(i)) return i;
        return -1;
    }
    // Opens under an item (a menu title), or at a point in owner coordinates.
    function openBelow(item) {
        const point = item.mapToItem(owner.popupOverlay, 0, item.height);
        openAtPoint(point.x, point.y);
    }
    function openAtPoint(px, py) {
        x = Math.round(px);
        y = Math.round(py);
        highlighted = -1;
        open();
    }
    function activate(index) {
        if (!usable(index)) return;
        const entry = entries[index];
        close();
        chosen(entry.action, entry.data);
    }
    function move(direction) {
        if (entries.length === 0) return;
        let next = highlighted;
        for (let n = 0; n < entries.length; n++) {
            next = (next + direction + entries.length) % entries.length;
            if (usable(next)) { highlighted = next; return; }
        }
    }
    onOpened: surface.forceActiveFocus()
    onClosed: dismissed()

    contentItem: WindowScale {
        id: surface
        devicePixelRatio: metrics.devicePixelRatio
        implicitWidth: panel.item ? panel.item.implicitWidth : 0
        implicitHeight: panel.item ? panel.item.implicitHeight : 0
        NativeWindowMetrics { id: metrics }
        Accessible.role: Accessible.PopupMenu
        Accessible.name: root.name
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Down) root.move(1);
            else if (event.key === Qt.Key_Up) root.move(-1);
            else if (event.key === Qt.Key_Home) { root.highlighted = -1; root.move(1); }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.activate(root.highlighted);
            else if (event.key === Qt.Key_Escape) root.close();
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) { const d = event.key === Qt.Key_Left ? -1 : 1; root.close(); root.stepped(d); }
            else return;
            event.accepted = true;
        }
        Loader {
            id: panel
            anchors.fill: parent
            sourceComponent: root.win98 ? memphis : platinum
        }
        Component {
            id: memphis
            Win98MenuPanel {
                // Names are data: an "&" in a folder name is literal.
                items: root.entries.map(function(e) {
                    if (e.separator) return { separator: true };
                    return { text: String(e.text).replace(/&/g, "&&"), shortcut: e.shortcut || "", enabled: e.enabled !== false && !e.header,
                        checked: e.checked === true, bold: e.bold === true || e.header === true };
                })
                highlighted: root.highlighted
                maxHeight: 0
                onHovered: function(index) { if (root.usable(index)) root.highlighted = index; }
                onClicked: function(index) { root.activate(index); }
                Accessible.name: root.name
            }
        }
        Component {
            id: platinum
            PlatinumMenuFrame {
                id: frame
                showHeader: false
                readonly property real textWidth: Math.max(80, PlatinumMetrics.widest(root.entries.map(function(e) { return e.text || ""; })))
                readonly property real keyWidth: PlatinumMetrics.smallWidest(root.entries.map(function(e) { return e.shortcut || ""; }))
                preferredWidth: PlatinumTokens.menuTextLeft + textWidth + (keyWidth > 1 ? PlatinumTokens.menuGap * 2 + keyWidth : 0) + PlatinumTokens.menuRightInset
                menuWidth: preferredWidth
                implicitWidth: preferredWidth
                maxHeight: 2000
                Repeater {
                    model: root.entries
                    Loader {
                        id: slot
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        sourceComponent: modelData.separator ? separatorRow : itemRow
                        Component {
                            id: separatorRow
                            Item {
                                implicitHeight: 9
                                Rectangle {
                                    x: 0; width: parent.width
                                    y: 4; height: PlatinumTokens.hairFor(WindowMetrics.ratio(parent))
                                    color: PlatinumTokens.bevelDark
                                }
                            }
                        }
                        Component {
                            id: itemRow
                            PlatinumMenuListRow {
                                objectName: "menuEntry-" + (slot.modelData.action || slot.index)
                                rowHeight: 22
                                name: slot.modelData.text || ""
                                mark: slot.modelData.checked === true ? "check" : ""
                                selected: slot.index === root.highlighted
                                enabled: root.usable(slot.index)
                                nameColor: slot.modelData.header ? PlatinumTokens.menuTextSecondary
                                    : enabled ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
                                Accessible.role: Accessible.MenuItem
                                Accessible.name: slot.modelData.text || ""
                                onEntered: if (root.usable(slot.index)) root.highlighted = slot.index
                                onClicked: root.activate(slot.index)
                                Text {
                                    visible: !!slot.modelData.shortcut
                                    text: slot.modelData.shortcut || ""
                                    textFormat: Text.PlainText
                                    color: parent.selected ? PlatinumTokens.highlightText
                                        : parent.enabled ? PlatinumTokens.menuTextSecondary : PlatinumTokens.menuTextOff
                                    font.family: PlatinumTokens.platinumFont
                                    font.pixelSize: PlatinumTokens.platinumSmall
                                    font.letterSpacing: PlatinumTokens.platinumTracking
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
