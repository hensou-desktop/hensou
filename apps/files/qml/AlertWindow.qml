import QtQuick
import QtQuick.Layouts
import Hensou
import Hensou.Host
import "Art.js" as Art

// A modal alert in its own native window: Mac OS 8's alert box (Platinum)
// or a Windows 98 message box (Memphis). Return runs the default button,
// Escape the cancel action. spec comes from Alerts.js.
Window {
    id: root
    required property var app
    required property var spec
    property var owner: null
    property bool answered: false
    signal finished(string action)

    readonly property bool win98: Theme.name === "win98"
    readonly property real u: 2 / Math.max(0.5, metrics.devicePixelRatio)
    readonly property real frameWidth: win98 ? 330 * u : 440

    title: spec.title || (win98 ? "Files" : "Alert")
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: owner ? Qt.WindowModal : Qt.ApplicationModal
    transientParent: owner
    color: win98 ? Win98Tokens.face : PlatinumTokens.menuSurface
    width: frameWidth
    height: Math.max(80, frame.item ? Math.ceil(frame.item.implicitHeight) : 160)
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height

    function present() {
        show();
        raise();
        requestActivate();
        Qt.callLater(function() { const b = root.buttonFor(root.spec.defaultAction); if (b) b.takeFocus(); });
    }
    function choose(action) {
        if (answered) return;
        answered = true;
        close();
        finished(action);
    }
    function buttonFor(action) {
        return frame.item ? frame.item.buttonFor(action) : null;
    }
    onClosing: function(close) { if (!answered) { answered = true; finished(spec.cancelAction); } }

    WindowScale {
        id: scale
        anchors.fill: parent
        devicePixelRatio: metrics.devicePixelRatio
        NativeWindowMetrics { id: metrics }
        Accessible.role: Accessible.AlertMessage
        Accessible.name: root.spec.message
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) root.choose(root.spec.cancelAction);
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                // Return runs the focused button in Memphis, the default in Platinum.
                const focused = frame.item ? frame.item.focusedAction() : "";
                root.choose(root.win98 && focused !== "" ? focused : root.spec.defaultAction);
            } else return;
            event.accepted = true;
        }
        Loader {
            id: frame
            width: parent.width
            sourceComponent: root.win98 ? memphis : platinum
        }
    }

    component Body: ColumnLayout {
        id: body
        spacing: root.win98 ? 8 * root.u : 10
        property real textWidth: 200
        FilesText {
            objectName: "alertMessage"
            Layout.preferredWidth: body.textWidth
            text: root.spec.message
            wrap: true
            bold: false
        }
        FilesText {
            objectName: "alertDetail"
            visible: !!root.spec.detail
            Layout.preferredWidth: body.textWidth
            text: root.spec.detail || ""
            wrap: true
            small: true
        }
        // The fingerprint stays whole and selectable, never elided.
        Rectangle {
            visible: !!root.spec.fingerprint
            Layout.preferredWidth: body.textWidth
            Layout.preferredHeight: print.implicitHeight + (root.win98 ? 6 * root.u : 8)
            color: root.win98 ? Win98Tokens.win : PlatinumTokens.field
            border.width: root.win98 ? root.u : PlatinumTokens.hairFor(metrics.devicePixelRatio)
            border.color: root.win98 ? Win98Tokens.sh : PlatinumTokens.bevelDark
            TextEdit {
                id: print
                objectName: "alertFingerprint"
                x: root.win98 ? 3 * root.u : 4
                y: root.win98 ? 3 * root.u : 4
                width: parent.width - 2 * x
                readOnly: true
                selectByMouse: true
                activeFocusOnTab: false
                wrapMode: TextEdit.WrapAnywhere
                textFormat: TextEdit.PlainText
                text: root.spec.fingerprint || ""
                color: root.win98 ? Win98Tokens.winText : PlatinumTokens.menuText
                selectionColor: root.win98 ? Win98Tokens.selection : PlatinumTokens.highlight
                font.family: root.win98 ? Win98Tokens.fontFamily : PlatinumTokens.platinumFont
                font.pixelSize: root.win98 ? Math.round(12.5 * root.u) : PlatinumTokens.platinumSmall
                Accessible.role: Accessible.StaticText
                Accessible.name: "Fingerprint " + text
            }
        }
    }

    component Buttons: Row {
        id: row
        property var labels: root.spec.buttons.map(function(b) { return b.text; })
        spacing: root.win98 ? 6 * root.u : 12
        function buttonFor(action) {
            for (let i = 0; i < repeater.count; i++) if (repeater.itemAt(i).action === action) return repeater.itemAt(i);
            return null;
        }
        function focusedAction() {
            for (let i = 0; i < repeater.count; i++) if (repeater.itemAt(i).item && repeater.itemAt(i).item.activeFocus) return repeater.itemAt(i).action;
            return "";
        }
        Repeater {
            id: repeater
            model: root.spec.buttons
            FilesButton {
                required property var modelData
                readonly property string action: modelData.action
                objectName: "alertButton-" + modelData.action
                text: modelData.text
                isDefault: modelData.action === root.spec.defaultAction
                roleLabels: row.labels
                onClicked: root.choose(modelData.action)
            }
        }
    }

    Component {
        id: platinum
        Item {
            implicitHeight: content.implicitHeight + 2 * 18 + 2 * PlatinumTokens.hairFor(metrics.devicePixelRatio)
            function buttonFor(a) { return buttons.buttonFor(a); }
            function focusedAction() { return buttons.focusedAction(); }
            // An alert box: a black edge, the raised bevel, no title.
            PlatinumBevel { anchors.fill: parent; color: PlatinumTokens.menuSurface }
            MouseArea { anchors.fill: parent; onPressed: root.startSystemMove() }
            RowLayout {
                id: content
                x: 18; y: 18
                width: parent.width - 36
                spacing: 16
                Image {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    sourceSize.width: Math.round(32 * metrics.devicePixelRatio)
                    sourceSize.height: Math.round(32 * metrics.devicePixelRatio)
                    source: Art.url("platinum", root.spec.art, "#000000", "")
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Body { textWidth: content.width - 48 }
                    Buttons { id: buttons; Layout.alignment: Qt.AlignRight }
                }
            }
        }
    }
    Component {
        id: memphis
        Item {
            implicitHeight: box.implicitHeight
            function buttonFor(a) { return buttons.buttonFor(a); }
            function focusedAction() { return buttons.focusedAction(); }
            Win98Window {
                id: box
                width: root.width
                title: root.spec.title || "Files"
                showClose: true
                onCloseClicked: root.choose(root.spec.cancelAction)
                ColumnLayout {
                    width: root.width - 22 * root.u
                    spacing: 10 * root.u
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10 * root.u
                        Image {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 32 * root.u
                            Layout.preferredHeight: 32 * root.u
                            smooth: false
                            sourceSize.width: 64
                            sourceSize.height: 64
                            source: Art.url("win98", root.spec.art, Win98Tokens.ink, "")
                        }
                        Body { textWidth: root.width - 80 * root.u }
                    }
                    Buttons { id: buttons; Layout.alignment: Qt.AlignHCenter }
                }
            }
            // Drag the caption to move the message box.
            MouseArea {
                x: 3 * root.u; y: 3 * root.u
                width: parent.width - 30 * root.u
                height: Win98Tokens.captionHeight * root.u
                onPressed: root.startSystemMove()
            }
        }
    }
}
