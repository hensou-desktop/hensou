import QtQuick
import QtQuick.Layouts
import Hensou
import Hensou.Host

Window {
    id: root
    required property var owner
    property string message: ""
    property string returnTarget: "dialog"
    title: "Hensou dialog"
    transientParent: owner
    modality: Qt.WindowModal
    flags: Qt.Dialog
    width: 440
    height: 240
    minimumWidth: 220
    minimumHeight: 160
    color: Theme.name === "win98" ? Win98Tokens.face : PlatinumTokens.menuSurface
    function openFrom(target, text) {
        returnTarget = target;
        message = text;
        show();
        requestActivate();
        Qt.callLater(function() { closeButton.takeFocus(); });
    }
    onVisibleChanged: if (!visible) Qt.callLater(function() { owner.restoreFocus(returnTarget); })
    WindowScale {
        anchors.fill: parent
        devicePixelRatio: metrics.devicePixelRatio
        NativeWindowMetrics { id: metrics }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: PlatinumTokens.menuRightInset
            spacing: PlatinumTokens.menuGap
            DemoLabel {
                text: root.message
                wrap: true
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            DemoButton {
                id: closeButton
                objectName: "closeDialog"
                text: "Close dialog"
                onClicked: root.close()
            }
        }
        Keys.onEscapePressed: root.close()
    }
}
