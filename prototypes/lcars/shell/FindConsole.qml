// PROTOTYPE — Find (Super+P, F1) as a work-area takeover. Scopes as in Win98's
// Find menu: All, Applications Ctrl+1, Windows Ctrl+2, Commands Ctrl+3, Address Ctrl+L.
import QtQuick
import "../tokens.js" as T
import ".."

Takeover {
    title: "Find"; code: "Super+P"; color: T.periwinkle
    Row {
        spacing: 30
        Column {
            spacing: 4
            Text { text: "SCOPE"; color: T.periwinkle; font.family: s.fam; font.pixelSize: 16 }
            Repeater {
                model: [ { t: "All", k: "Super+P", on: true }, { t: "Applications", k: "Ctrl+1" }, { t: "Windows", k: "Ctrl+2" }, { t: "Commands", k: "Ctrl+3" }, { t: "Address", k: "Ctrl+L" } ]
                delegate: Pill { required property var modelData; width: 200; height: 56; leftCap: false; text: modelData.t; sub: modelData.k; color: modelData.on ? T.gold : T.lilac; fam: s.fam; px: 20 }
            }
        }
        Column {
            width: 900; spacing: 8
            Rectangle {
                width: parent.width; height: 64; color: T.space; border.color: T.periwinkle; border.width: 3; radius: 32
                Text { x: 28; anchors.verticalCenter: parent.verticalCenter; text: "gho▏"; color: T.peach; font.family: s.fam; font.pixelSize: 38 }
                Text { anchors.right: parent.right; anchors.rightMargin: 28; anchors.verticalCenter: parent.verticalCenter; text: "6 MATCHES"; color: T.periwinkle; font.family: s.fam; font.pixelSize: 20 }
            }
            Text { text: "WINDOWS"; color: T.periwinkle; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "nix build"; value: "Ghostty"; tag: "win"; selected: true; fam: s.fam; color: T.peach; px: 26 }
            Line { label: "ssh aka"; value: "Ghostty, portable monitor"; tag: "win"; fam: s.fam; color: T.peach; px: 26 }
            Text { text: "APPLICATIONS"; color: T.periwinkle; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Ghostty"; value: "new window"; tag: "app"; fam: s.fam; color: T.lilac; px: 26 }
            Line { label: "GHex"; tag: "app"; fam: s.fam; color: T.lilac; px: 26 }
            Text { text: "COMMANDS"; color: T.periwinkle; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Go to address…"; value: "Ctrl+L"; tag: "cmd"; fam: s.fam; color: T.sunset; px: 26 }
            Line { label: "Switch desktop theme"; value: "Super+D"; tag: "cmd"; fam: s.fam; color: T.sunset; px: 26 }
        }
    }
}
