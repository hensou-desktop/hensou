import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Hensou
import Hensou.Host

Dialog {
    id: root
    required property var owner
    property string message: ""
    property string returnTarget: "dialog"
    title: "Hensou dialog"
    parent: owner.contentItem
    popupType: Popup.Window
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: PlatinumTokens.menuRightInset
    header: null
    footer: null
    Accessible.name: title
    width: 440
    height: 240
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
        focusCloseTimer.restart();
    }
    onClosed: if (owner && owner.visible) returnFocusTimer.restart()
    Timer {
        id: focusCloseTimer
        interval: 0
        onTriggered: if (root.visible) closeButton.takeFocus()
    }
    Timer {
        id: returnFocusTimer
        interval: 0
        onTriggered: if (root.owner && root.owner.visible) root.owner.restoreFocus(root.returnTarget)
    }
    contentItem: WindowScale {
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
