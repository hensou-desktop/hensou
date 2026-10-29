import QtQuick

// A Platinum check box: a sunken well with a black edge and a check mark.
// The box sits centred in the menu gutter (PlatinumMenuCheckRow), so its label
// starts on the text edge like every other row.
Item {
    id: root

    property bool checked: false
    property bool down: false
    // Existing shell rows own their hit rectangle. Standalone callers opt in.
    property bool interactive: false
    property string text: ""
    activeFocusOnTab: enabled && interactive
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: if (enabled && interactive) toggled(!checked)
    Keys.onSpacePressed: event => {
        if (enabled && interactive) { toggled(!checked); event.accepted = true; }
    }
    signal toggled(bool checked)

    implicitWidth: 14 + (text !== "" ? 6 + label.implicitWidth : 0)
    implicitHeight: 14

    PlatinumBevel {
        width: 14
        height: 14
        sunken: true
        color: root.down ? PlatinumTokens.bevelDark : PlatinumTokens.well
        lightColor: PlatinumTokens.bevelLight
        darkColor: PlatinumTokens.bevelDark
    }

    PlatinumIcon {
        x: 2
        y: 2
        visible: root.checked
        name: "check"
        size: 10
        color: root.enabled ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
    }
    Text {
        id: label
        x: 20
        width: Math.max(0, Math.min(implicitWidth, root.width - x))
        visible: root.text !== ""
        text: root.text
        elide: Text.ElideRight
        color: root.enabled ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2 * PlatinumTokens.hairFor(WindowMetrics.ratio(root))
        color: "transparent"
        border.color: PlatinumTokens.focusRing
        border.width: PlatinumTokens.hairFor(WindowMetrics.ratio(root))
        visible: root.interactive && root.activeFocus
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive && root.enabled
        onPressed: root.forceActiveFocus()
        onClicked: root.toggled(!root.checked)
    }
}

