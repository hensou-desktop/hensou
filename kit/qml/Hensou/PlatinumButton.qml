import QtQuick

// A Platinum push button. Buttons that share a role share one width: the
// caller passes the width of the role's longest label (see
// PlatinumMetrics.buttonWidth), so a column of Connect / Disconnect / Pair
// ends on one edge and starts on one edge.
//
// A press sinks the bevel and darkens the face, as Mac OS 8 did. An icon
// button (the × forget box) passes icon instead of text and is square.
//
// The face takes PlatinumTokens.radiusSmall. The default ring and the focus ring
// sit outside it, so their radii grow by their distance from the face;
// that keeps all three corners concentric at any hair width.
Item {
    id: root

    property string text: ""
    property string icon: ""
    // A fixed width for the role. 0 means the label's own width.
    property real fixedWidth: 0
    // Mac OS's default button: a second ring, the one Enter runs.
    property bool isDefault: false
    // The keyboard's current target, where the bar has none (notification
    // actions). A ring in the highlight colour.
    property bool focused: false
    property bool onBar: false
    property string keyHint: ""
    property bool keyboardEnabled: true
    property bool keyDown: false
    activeFocusOnTab: enabled && keyboardEnabled
    Accessible.role: Accessible.Button
    Accessible.name: text || icon
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onPressed: event => {
        if (!keyboardEnabled || !enabled) return;
        if (event.key === Qt.Key_Space) { keyDown = true; event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            clicked(); event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Space && keyDown) {
            keyDown = false; if (enabled && activeFocus) clicked(); event.accepted = true;
        }
    }
    onActiveFocusChanged: if (!activeFocus) keyDown = false
    onEnabledChanged: if (!enabled) keyDown = false
    signal clicked

    readonly property bool hovered: area.containsMouse
    readonly property bool down: (area.pressed && area.containsMouse) || keyDown
    readonly property real ring: isDefault ? 2 * PlatinumTokens.hairFor(WindowMetrics.ratio(root)) : 0

    implicitHeight: (onBar ? 20 : PlatinumTokens.menuButtonHeight) + 2 * ring
    implicitWidth: (fixedWidth > 0 ? fixedWidth
        : icon !== "" && text === "" ? PlatinumTokens.menuButtonHeight
        : label.implicitWidth + 20) + 2 * ring
    opacity: 1

    Rectangle {
        visible: root.isDefault
        anchors.fill: parent
        color: "transparent"
        border.width: PlatinumTokens.hairFor(WindowMetrics.ratio(root))
        border.color: PlatinumTokens.menuEdge
        radius: PlatinumTokens.radiusSmall + root.ring
    }

    PlatinumBevel {
        id: face
        anchors.fill: parent
        anchors.margins: root.ring
        radius: PlatinumTokens.radiusSmall
        sunken: root.down
        bevelled: !root.onBar || PlatinumTokens.barBevelled
        edgeColor: root.onBar ? PlatinumTokens.barButtonEdge : PlatinumTokens.menuEdge
        color: root.down ? PlatinumTokens.well : root.onBar ? PlatinumTokens.barButton : PlatinumTokens.raised
    }

    Rectangle {
        visible: root.focused || (root.keyboardEnabled && root.activeFocus)
        anchors.fill: face
        anchors.margins: -2 * PlatinumTokens.hairFor(WindowMetrics.ratio(root))
        color: "transparent"
        radius: PlatinumTokens.radiusSmall + 2 * PlatinumTokens.hairFor(WindowMetrics.ratio(root))
        border.width: 2 * PlatinumTokens.hairFor(WindowMetrics.ratio(root))
        border.color: PlatinumTokens.highlight
    }

    Text {
        id: label
        visible: root.text !== ""
        anchors.centerIn: face
        width: Math.min(implicitWidth, face.width - 8)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.keyHint !== "" ? root.keyHint + "  " + root.text : root.text
        textFormat: Text.PlainText
        color: !root.enabled ? PlatinumTokens.menuTextOff : root.onBar ? PlatinumTokens.barText : PlatinumTokens.menuText
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
    }

    PlatinumIcon {
        visible: root.icon !== ""
        anchors.centerIn: face
        name: root.icon
        size: 8
        color: root.enabled ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
    }

    MouseArea {
        id: area
        anchors.fill: parent
        // The hit area never drops below 28 px tall.
        anchors.topMargin: Math.min(0, (root.height - 28) / 2)
        anchors.bottomMargin: Math.min(0, (root.height - 28) / 2)
        enabled: root.enabled
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
