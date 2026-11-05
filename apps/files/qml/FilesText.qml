import QtQuick
import Hensou

// Text in the current theme's face: ChicagoFLF (Platinum) or W95FA Grid on
// its unit grid (Memphis). Data text never takes access marks.
Loader {
    id: root
    property string text: ""
    // An explicit colour; transparent means the theme's text colour.
    property color color: "transparent"
    property bool bold: false
    // Platinum names aliases in italics; Memphis has no italic face and
    // marks shortcuts with an arrow instead.
    property bool italic: false
    property bool small: false
    property bool wrap: false
    property bool disabledLook: false
    property bool onWell: false
    property int horizontalAlignment: Text.AlignLeft
    property int maximumLineCount: 1000
    readonly property bool truncated: item ? item.truncated : false
    readonly property bool win98: Theme.name === "win98"
    sourceComponent: win98 ? memphis : platinum
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    Component {
        id: platinum
        Text {
            width: root.width > 0 ? root.width : implicitWidth
            text: root.text
            textFormat: Text.PlainText
            wrapMode: root.wrap ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
            elide: root.wrap ? Text.ElideNone : Text.ElideRight
            maximumLineCount: root.maximumLineCount
            horizontalAlignment: root.horizontalAlignment
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: root.small ? PlatinumTokens.platinumSmall : 13
            font.letterSpacing: PlatinumTokens.platinumTracking
            font.italic: root.italic
            font.bold: false
            color: root.color.a > 0 ? root.color : root.disabledLook ? PlatinumTokens.menuTextOff : PlatinumTokens.menuText
        }
    }
    Component {
        id: memphis
        Win98Text {
            width: root.width > 0 ? root.width : implicitWidth
            text: root.text
            accessMarks: false
            wrap: root.wrap
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: root.maximumLineCount
            horizontalAlignment: root.horizontalAlignment
            bold: root.bold
            disabledLook: root.disabledLook
            color: root.color.a > 0 ? root.color : root.onWell ? Win98Tokens.winText : Win98Tokens.text
        }
    }
}
