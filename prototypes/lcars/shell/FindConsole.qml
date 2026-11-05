// PROTOTYPE — Find (Super+P, F1): the omni service's lists in one console.
// Scopes as in Win98's Find menu: All, Applications Ctrl+1, Windows Ctrl+2,
// Commands Ctrl+3, Address Ctrl+L.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    property var screen
    readonly property var s: screen
    anchors.fill: parent
    Rectangle { x: s.f.work.x; y: s.f.work.y; width: s.f.work.w; height: s.f.work.h; color: "#c8000000" }
    Item {
        id: con
        width: 820; height: 600
        x: s.f.work.x + (s.f.work.w - width) / 2; y: s.f.work.y + 60
        Rectangle { anchors.fill: parent; color: T.space }
        Elbow { corner: "tl"; armW: 120; barH: 30; width: 230; height: 90; color: T.periwinkle }
        Rectangle { x: 234; width: parent.width - 234; height: 30; color: T.periwinkle; topRightRadius: 15; bottomRightRadius: 15
            Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; text: "FIND  SUPER+P"; color: T.space; font.family: s.fam; font.pixelSize: 22 } }
        Rectangle { y: 94; width: 120; height: parent.height - 94; color: T.lilac; bottomLeftRadius: 30 }
        Column {
            x: 0; y: 94; width: 120; spacing: 4
            Repeater {
                model: [ { t: "All", k: "Super+P", on: true }, { t: "Apps", k: "Ctrl+1" }, { t: "Windows", k: "Ctrl+2" }, { t: "Commands", k: "Ctrl+3" }, { t: "Address", k: "Ctrl+L" } ]
                delegate: Pill { required property var modelData; width: 120; height: 50; leftCap: false; rightCap: false; text: modelData.t; sub: modelData.k; color: modelData.on ? T.gold : T.lilac; fam: s.fam; px: 18 }
            }
        }
        Column {
            x: 140; y: 46; width: parent.width - 156; spacing: 6
            Rectangle {
                width: parent.width; height: 52; color: T.space; border.color: T.periwinkle; border.width: 2; radius: 26
                Text { x: 22; anchors.verticalCenter: parent.verticalCenter; text: "gho▏"; color: T.peach; font.family: s.fam; font.pixelSize: 30 }
                Text { anchors.right: parent.right; anchors.rightMargin: 22; anchors.verticalCenter: parent.verticalCenter; text: "6 MATCHES"; color: T.periwinkle; font.family: s.fam; font.pixelSize: 18 }
            }
            Text { text: "WINDOWS"; color: T.periwinkle; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "nix build"; value: "Ghostty"; tag: "win"; selected: true; fam: s.fam; color: T.peach }
            Line { label: "ssh myoko"; value: "Ghostty, laptop"; tag: "win"; fam: s.fam; color: T.peach }
            Text { text: "APPLICATIONS"; color: T.periwinkle; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Ghostty"; value: "new window"; tag: "app"; fam: s.fam; color: T.lilac }
            Line { label: "GHex"; tag: "app"; fam: s.fam; color: T.lilac }
            Text { text: "COMMANDS"; color: T.periwinkle; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Go to address…"; value: "Ctrl+L"; tag: "cmd"; fam: s.fam; color: T.sunset }
            Line { label: "Switch desktop theme"; value: "Super+D"; tag: "cmd"; fam: s.fam; color: T.sunset }
        }
    }
}
