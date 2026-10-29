import QtQuick
import Hensou

Loader {
    id: root
    property string text: ""
    property bool wrap: false
    implicitWidth: item ? item.implicitWidth : 0
    implicitHeight: item ? item.implicitHeight : 0
    sourceComponent: Theme.name === "win98" ? win98 : platinum
    Component {
        id: platinum
        Text {
            text: root.text
            textFormat: Text.PlainText
            wrapMode: root.wrap ? Text.WrapAnywhere : Text.NoWrap
            elide: root.wrap ? Text.ElideNone : Text.ElideRight
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumText
            font.letterSpacing: PlatinumTokens.platinumTracking
            color: PlatinumTokens.menuText
            Accessible.role: Accessible.StaticText
            Accessible.name: root.text
        }
    }
    Component {
        id: win98
        Win98Text {
            text: root.text
            wrap: root.wrap
            accessMarks: false
            Accessible.role: Accessible.StaticText
            Accessible.name: root.text
        }
    }
}
