import QtQuick
import Hensou
import Hensou.Host
import "Art.js" as Art

// A modal alert in its own native window: Mac OS 8's alert box (Platinum)
// or a Memphis message box (Memphis). Return runs the default button,
// Escape the cancel action. spec comes from Alerts.js.
Window {
    id: root
    required property var app
    required property var spec
    property var owner: null
    property bool answered: false
    signal finished(string action)

    readonly property bool memphis: Theme.name === "memphis"
    readonly property real u: 2 / Math.max(0.5, metrics.devicePixelRatio)
    // Logical, not units: the unit is only known after the window maps.
    readonly property real frameWidth: 440

    title: spec.title || (memphis ? "Files" : "Alert")
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: owner ? Qt.WindowModal : Qt.ApplicationModal
    transientParent: owner
    color: memphis ? MemphisTokens.face : PlatinumTokens.menuSurface
    width: frameWidth
    readonly property real wantedHeight: Math.max(80, frame.item ? Math.ceil(frame.item.implicitHeight) : 160)
    height: wantedHeight
    // The window's scale settles after it maps, and the compositor may answer
    // an earlier size afterwards. Ask again until the window fits its text.
    onHeightChanged: if (Math.abs(height - wantedHeight) > 0.5) refit.restart()
    onWantedHeightChanged: if (Math.abs(height - wantedHeight) > 0.5) refit.restart()
    property int refits: 0
    Timer {
        id: refit
        interval: 50
        // A compositor that keeps another size wins after a few tries.
        onTriggered: if (root.refits++ < 8) { root.height = root.wantedHeight; root.height = Qt.binding(function() { return root.wantedHeight; }); }
    }
    minimumWidth: frameWidth
    maximumWidth: frameWidth

    // Escape always answers with the cancel action, wherever focus is.
    Shortcut { sequence: "Escape"; onActivated: root.choose(root.spec.cancelAction) }
    // Return runs the focused button in Memphis, the default one in Platinum.
    Shortcut {
        sequences: ["Return", "Enter"]
        onActivated: {
            const focused = frame.item ? frame.item.focusedAction() : "";
            root.choose(root.memphis && focused !== "" ? focused : root.spec.defaultAction);
        }
    }
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
        Loader {
            id: frame
            width: parent.width
            sourceComponent: root.memphis ? memphis : platinum
        }
    }

    // Fixed widths, so wrapped text has its height before the window maps.
    component Body: Column {
        id: body
        spacing: root.memphis ? 8 * root.u : 10
        property real textWidth: 200
        width: textWidth
        FilesText {
            objectName: "alertMessage"
            width: body.textWidth
            text: root.spec.message
            wrap: true
        }
        FilesText {
            objectName: "alertDetail"
            visible: !!root.spec.detail
            width: body.textWidth
            text: root.spec.detail || ""
            wrap: true
            small: true
        }
        // The fingerprint stays whole and selectable, never elided.
        Rectangle {
            visible: !!root.spec.fingerprint
            width: body.textWidth
            height: fingerprintText.implicitHeight + (root.memphis ? 6 * root.u : 8)
            color: root.memphis ? MemphisTokens.win : PlatinumTokens.field
            border.width: root.memphis ? root.u : PlatinumTokens.hairFor(metrics.devicePixelRatio)
            border.color: root.memphis ? MemphisTokens.sh : PlatinumTokens.bevelDark
            TextEdit {
                id: fingerprintText
                objectName: "alertFingerprint"
                x: root.memphis ? 3 * root.u : 4
                y: root.memphis ? 3 * root.u : 4
                width: parent.width - 2 * x
                readOnly: true
                selectByMouse: true
                activeFocusOnTab: false
                wrapMode: TextEdit.WrapAnywhere
                textFormat: TextEdit.PlainText
                text: root.spec.fingerprint || ""
                color: root.memphis ? MemphisTokens.winText : PlatinumTokens.menuText
                selectionColor: root.memphis ? MemphisTokens.selection : PlatinumTokens.highlight
                font.family: root.memphis ? MemphisTokens.fontFamily : PlatinumTokens.platinumFont
                font.pixelSize: root.memphis ? Math.round(12.5 * root.u) : PlatinumTokens.platinumSmall
                Accessible.role: Accessible.StaticText
                Accessible.name: "Fingerprint " + text
            }
        }
    }

    component Buttons: Row {
        id: row
        property var labels: root.spec.buttons.map(function(b) { return b.text; })
        spacing: root.memphis ? 6 * root.u : 12
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
            Item {
                id: content
                x: 18; y: 18
                width: parent.width - 36
                implicitHeight: Math.max(32, textColumn.height)
                Image {
                    width: 32; height: 32
                    sourceSize.width: Math.round(32 * metrics.devicePixelRatio)
                    sourceSize.height: Math.round(32 * metrics.devicePixelRatio)
                    source: Art.url("platinum", root.spec.art, "#000000", "")
                }
                Column {
                    id: textColumn
                    x: 48
                    width: content.width - 48
                    spacing: 16
                    Body { textWidth: textColumn.width }
                    Buttons { id: buttons; anchors.right: parent.right }
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
            MemphisWindow {
                id: box
                width: root.width
                title: root.spec.title || "Files"
                showClose: true
                onCloseClicked: root.choose(root.spec.cancelAction)
                Column {
                    width: root.width - 22 * root.u
                    spacing: 10 * root.u
                    Row {
                        spacing: 10 * root.u
                        Image {
                            width: 32 * root.u; height: 32 * root.u
                            smooth: false
                            sourceSize.width: 64
                            sourceSize.height: 64
                            source: Art.url("memphis", root.spec.art, MemphisTokens.ink, "")
                        }
                        Body { textWidth: root.width - 80 * root.u }
                    }
                    Buttons { id: buttons; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }
            // Drag the caption to move the message box.
            MouseArea {
                x: 3 * root.u; y: 3 * root.u
                width: parent.width - 30 * root.u
                height: MemphisTokens.captionHeight * root.u
                onPressed: root.startSystemMove()
            }
        }
    }
}
