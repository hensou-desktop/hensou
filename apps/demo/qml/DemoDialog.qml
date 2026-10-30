import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Hensou
import Hensou.Host

Popup {
    id: root
    required property var owner
    property string message: ""
    property string returnTarget: "dialog"
    property string title: "Hensou dialog"
    ModalInputGuard { ownerWindow: root.owner; active: root.visible && root.modal }
    parent: owner.popupOverlay
    popupType: Popup.Window
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: PlatinumTokens.menuRightInset
    // Demo sizing: a fixed request, not layout policy. Centred on the
    // 640 x 480 owner it requests (100, 120) (docs/host.md), and the modal
    // test needs the Increment button outside it for the blocked-parent
    // click. The long-message test shrinks it to force scrolling.
    width: 440
    height: 240
    readonly property real requestedX: Math.round((owner.width - width) / 2)
    readonly property real requestedY: Math.round((owner.height - height) / 2)
    x: requestedX
    y: requestedY
    background: WindowScale {
        devicePixelRatio: metrics.devicePixelRatio
        Loader {
            anchors.fill: parent
            sourceComponent: Theme.name === "win98" ? win98Frame : platinumFrame
        }
        Component { id: win98Frame; Win98Bevel { variant: "window" } }
        Component { id: platinumFrame; PlatinumBevel { color: PlatinumTokens.menuSurface } }
    }
    function openFrom(target, text) {
        returnTarget = target;
        message = text;
        open();
    }
    onClosed: if (owner && owner.visible) returnFocusTimer.restart()
    onOpened: {
        contentItem.forceActiveFocus();
        closeButton.takeFocus();
    }
    Timer {
        id: returnFocusTimer
        interval: 0
        onTriggered: if (root.owner && root.owner.visible) root.owner.restoreFocus(root.returnTarget)
    }
    contentItem: WindowScale {
        Accessible.role: Accessible.Dialog
        Accessible.name: root.title
        Keys.onEscapePressed: root.close()
        devicePixelRatio: metrics.devicePixelRatio
        NativeWindowMetrics { id: metrics }
        ColumnLayout {
            anchors.fill: parent
            spacing: PlatinumTokens.menuGap
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Flickable {
                    id: document
                    objectName: "dialogDocument"
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: messageLabel.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    activeFocusOnTab: true
                    Keys.onPressed: function(event) {
                        let next = contentY;
                        if (event.key === Qt.Key_End) next = contentHeight;
                        else if (event.key === Qt.Key_Home) next = 0;
                        else if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) next += height / 2;
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) next -= height / 2;
                        else return;
                        contentY = Math.max(0, Math.min(next, contentHeight - height));
                        event.accepted = true;
                    }
                    DemoLabel {
                        id: messageLabel
                        objectName: "dialogMessage"
                        width: document.width - scrollbar.width
                        height: implicitHeight
                        text: root.message
                        wrap: true
                    }
                }
                Loader {
                    id: scrollbar
                    anchors.right: parent.right
                    height: parent.height
                    width: item ? item.implicitWidth : 0
                    // Keep the gutter stable: wrapping must not decide its own width.
                    visible: document.contentHeight > document.height
                    sourceComponent: Theme.name === "win98" ? win98Bar : platinumBar
                }
                Component { id: platinumBar; PlatinumScrollBar { flickable: document } }
                Component { id: win98Bar; Win98ScrollBar { flickable: document } }
            }
            DemoButton {
                id: closeButton
                wantsFocus: root.visible
                objectName: "closeDialog"
                text: "Close dialog"
                onClicked: root.close()
            }
        }
    }
}
