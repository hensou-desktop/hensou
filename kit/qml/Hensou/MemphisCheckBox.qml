import QtQuick

// A Memphis check box: a 13-u sunken white box with a 7-u check, the label
// 5 u to its right. Disabled: a face-coloured box, a grey check and a grey
// embossed label. Focus: a dotted rectangle around the label. Space or a
// click toggles; the owner sets checked from toggled(!root.checked).
FocusScope {
    id: root
    Accessible.role: Accessible.CheckBox
    Accessible.name: MemphisTokens.plainText(text)


    property string text: ""           // "&" marks the access key
    property bool checked: false
    property bool showFocus: false
    property bool showPressed: false

    Accessible.checked: checked
    Accessible.checkable: true
    Accessible.onToggleAction: if (enabled) toggled(!root.checked)
    signal toggled(bool checked)

    readonly property real u: 2 / WindowMetrics.ratio(root)
    readonly property bool pressing: showPressed || (area.pressed && area.containsMouse)

    implicitWidth: MemphisTokens.checkBox * u + (text !== "" ? 5 * u + label.implicitWidth : 0)
    implicitHeight: MemphisTokens.checkBox * u
    activeFocusOnTab: enabled

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space) {
            root.toggled(!root.checked);
            event.accepted = true;
        }
    }

    MemphisBevel {
        id: box
        width: MemphisTokens.checkBox * root.u
        height: width
        variant: "field"
        // Memphis greys the box while the pointer holds it, and when disabled.
        color: root.enabled && !root.pressing ? MemphisTokens.win : MemphisTokens.face

        MemphisIcon {
            visible: root.checked
            x: 3 * root.u; y: 3 * root.u
            name: "check"
            color: root.enabled ? MemphisTokens.winText : MemphisTokens.gray
        }
    }

    MemphisText {
        id: label
        visible: root.text !== ""
        x: box.width + 5 * root.u
        width: Math.min(implicitWidth, root.width - x)
        text: root.text
        disabledLook: !root.enabled
    }

    MemphisFocusRect {
        visible: root.enabled && root.text !== "" && (root.showFocus || root.activeFocus)
        x: label.x - root.u; y: -root.u
        width: label.width + 2 * root.u
        height: label.height + 2 * root.u
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        onPressed: root.forceActiveFocus()
        onClicked: root.toggled(!root.checked)
    }
}
