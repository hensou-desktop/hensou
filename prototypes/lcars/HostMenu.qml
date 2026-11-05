// PROTOTYPE — overflow menu for hosts and actions. Opens at window level (rule 8).
import QtQuick
import "tokens.js" as T

Rectangle {
    id: m
    property var items: []      // [{ name, detail, kind }]
    property string fam: ""
    property string title: "Hosts"
    color: T.space
    border.color: T.periwinkle
    border.width: 0
    width: 300
    height: col.height + 16
    Column {
        id: col
        x: 8; y: 8; width: m.width - 16; spacing: T.gap
        Pill { width: parent.width; height: 26; text: m.title; fam: m.fam; color: T.periwinkle; rightCap: false; px: 16 }
        Repeater {
            model: m.items
            delegate: Pill {
                required property var modelData
                width: col.width; height: 44
                text: modelData.name
                sub: modelData.detail
                fam: m.fam
                leftCap: false
                color: modelData.kind === "trash" ? T.alert : (modelData.detail === "Host key changed" ? T.alert : (modelData.kind === "ssh" ? T.periwinkle : T.sunset))
            }
        }
    }
}
