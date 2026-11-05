pragma ComponentBehavior: Bound

import QtQuick

// A Memphis text field: 21 u tall, sunken, white (dark in dark grey), the
// text 4 u in, a 1-u caret that blinks (steady under reduced motion).
// Selected text takes the selection colours. Disabled: face background
// and grey text. The text draws through the same 25 px / scale route as
// MemphisText, so it stays on the grid.
FocusScope {
    id: root
    Accessible.name: placeholder


    property alias text: input.text
    property alias echoMode: input.echoMode
    property alias readOnly: input.readOnly
    property alias maximumLength: input.maximumLength
    property alias input: input
    property string placeholder: ""
    // Draw a steady caret without keyboard focus (galleries).
    property bool showCaret: false
    // Units on the right the text keeps clear of (a combo's drop button).
    property real rightInsetUnits: 0

    signal edited(string text)
    signal accepted
    // Every key before the field takes it; a handler that accepts the
    // event keeps it from the field (the Find window's list keys).
    signal keyPressed(var event)

    readonly property real u: 2 / WindowMetrics.ratio(root)
    readonly property real k: (root.u / 2)

    implicitWidth: 120 * u
    implicitHeight: MemphisTokens.fieldHeight * u
    activeFocusOnTab: enabled

    MemphisBevel {
        anchors.fill: parent
        variant: "field"
        color: root.enabled ? MemphisTokens.win : MemphisTokens.face
    }

    Item {
        id: clipper
        x: 2 * root.u; y: 2 * root.u
        width: root.width - 4 * root.u - root.rightInsetUnits * root.u
        height: root.height - 4 * root.u
        clip: true

        MemphisText {
            visible: input.text === "" && root.placeholder !== ""
            x: 2 * root.u
            y: 2 * root.u
            width: clipper.width - 4 * root.u
            text: root.placeholder
            accessMarks: false
            color: MemphisTokens.gray
        }

        TextInput {
            id: input
        Accessible.name: root.Accessible.name
            x: 2 * root.u
            y: 2 * root.u
            width: (clipper.width - 4 * root.u) / root.k
            height: MemphisTokens.lineUnits * 2
            transformOrigin: Item.TopLeft
            scale: root.k
            focus: true
            enabled: root.enabled
            clip: false
            renderType: Text.NativeRendering
            color: root.enabled ? MemphisTokens.winText : MemphisTokens.gray
            selectionColor: MemphisTokens.selection
            selectedTextColor: MemphisTokens.selectionText
            selectByMouse: true
            // W95FA has no bullet; Memphis masked with asterisks.
            passwordCharacter: "*"
            font.family: MemphisTokens.fontFamily
            font.pixelSize: MemphisTokens.fontRaster
            font.hintingPreference: Font.PreferNoHinting
            font.kerning: false
            cursorVisible: root.enabled && (root.activeFocus || root.showCaret)
            onTextEdited: root.edited(text)
            onAccepted: root.accepted()
            Keys.onPressed: event => root.keyPressed(event)

            cursorDelegate: Rectangle {
                id: caret
                width: 2          // 1 u
                height: MemphisTokens.lineUnits * 2
                color: MemphisTokens.winText
                visible: input.cursorVisible && blink.on
                Timer {
                    id: blink
                    property bool on: true
                    interval: 530
                    repeat: true
                    running: input.cursorVisible && !MemphisTokens.reducedMotion && !root.showCaret
                    onRunningChanged: on = true
                    onTriggered: on = !on
                }
            }
        }
    }
}
