import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Hensou
import Hensou.Host

Popup {
    id: root
    required property var owner
    required property var entries
    property int highlighted: 0
    property string returnTarget: "menu"
    signal chosen(string action)
    popupType: Popup.Window
    padding: 0
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: owner.contentItem
    implicitWidth: surface.implicitWidth
    implicitHeight: surface.implicitHeight
    background: Item {}
    function openAt(control) {
        const point = control.mapToItem(owner.contentItem, 0, control.height);
        x = point.x;
        y = point.y;
        returnTarget = owner.state.focusTarget;
        highlighted = 0;
        open();
    }
    function activate(index) {
        const entry = entries[index];
        if (!entry || entry.enabled === false) return;
        close();
        chosen(entry.action);
    }
    onOpened: surface.forceActiveFocus()
    onClosed: Qt.callLater(function() { owner.restoreFocus(returnTarget); })
    contentItem: WindowScale {
        id: surface
        devicePixelRatio: metrics.devicePixelRatio
        implicitWidth: panel.item ? panel.item.implicitWidth : 0
        implicitHeight: panel.item ? panel.item.implicitHeight : 0
        NativeWindowMetrics { id: metrics }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                const direction = event.key === Qt.Key_Down ? 1 : -1;
                let next = root.highlighted;
                do { next = (next + direction + root.entries.length) % root.entries.length; }
                while (root.entries[next].enabled === false && next !== root.highlighted);
                root.highlighted = next;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) root.activate(root.highlighted);
            else return;
            event.accepted = true;
        }
        Loader {
            id: panel
            anchors.fill: parent
            sourceComponent: Theme.name === "win98" ? win98 : platinum
        }
        Component {
            id: win98
            Win98MenuPanel {
                items: root.entries
                highlighted: root.highlighted
                onHovered: function(index) { root.highlighted = index; }
                onClicked: function(index) { root.activate(index); }
                Accessible.role: Accessible.PopupMenu
                Accessible.name: "Demo actions"
            }
        }
        Component {
            id: platinum
            PlatinumMenuFrame {
                showHeader: false
                // Existing menu-width token; not a new demo drawing decision.
                preferredWidth: PlatinumTokens.menuTextLeft + 300 + PlatinumTokens.menuRightInset
                menuWidth: preferredWidth
                implicitWidth: preferredWidth
                Repeater {
                    model: root.entries
                    PlatinumMenuListRow {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        name: modelData.text
                        selected: index === root.highlighted
                        enabled: modelData.enabled !== false
                        nameColor: enabled ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
                        Accessible.role: Accessible.MenuItem
                        Accessible.name: modelData.text
                        onEntered: root.highlighted = index
                        onClicked: root.activate(index)
                    }
                }
            }
        }
        Component.onCompleted: forceActiveFocus()
    }
}
