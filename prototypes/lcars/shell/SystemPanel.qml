// PROTOTYPE — the system menu, from the top elbow (the Apple menu / Start menu).
// Same rows as themes/platinum/menu-models.js apple() and Win98's Start menu.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    property var screen
    readonly property var s: screen
    Panel {
        x: s.f.armW + 4; y: s.f.topH
        width: 700; height: 640
        color: T.gold; fam: s.fam; title: "Myoko"; code: "Super+Esc locks"
        Column {
            width: parent.width; spacing: 10
            Row {
                spacing: 24
                Repeater {
                    model: [ { k: "NixOS", v: "25.11" }, { k: "Generation", v: "system-61" }, { k: "Uptime", v: "3 d 4 h" }, { k: "Revision", v: "8c22538" } ]
                    delegate: Column {
                        required property var modelData
                        Text { text: modelData.k.toUpperCase(); color: T.lilac; font.family: s.fam; font.pixelSize: 14 }
                        Text { text: modelData.v; color: T.peach; font.family: s.fam; font.pixelSize: 26 }
                    }
                }
            }
            Text { text: "CONTROL PANELS"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Flow {
                width: parent.width; spacing: 4
                Repeater {
                    model: [ { t: "Appearance", c: T.sunset }, { t: "Bluetooth", c: T.periwinkle }, { t: "Brightness", c: T.peach },
                             { t: "Remote builds", c: T.lilac }, { t: "Sound", c: T.peach }, { t: "Wi-Fi", c: T.periwinkle } ]
                    delegate: Pill { required property var modelData; width: 140; height: 40; leftCap: false; rightCap: false; text: modelData.t; color: modelData.c; fam: s.fam; px: 18 }
                }
            }
            Text { text: "RECENT APPLICATIONS"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Column {
                width: parent.width; spacing: 2
                Line { label: "Ghostty"; tag: "app"; fam: s.fam; color: T.peach }
                Line { label: "Files"; tag: "app"; fam: s.fam; color: T.lilac; selected: true }
                Line { label: "Forgerie"; tag: "web"; value: "web app"; fam: s.fam; color: T.sunset }
                Line { label: "Jellyfin"; tag: "web"; value: "web app"; fam: s.fam; color: T.sunset }
            }
            Line { label: "Find…"; value: "Super+P"; tag: "?"; fam: s.fam; color: T.periwinkle }
            Row {
                spacing: 4
                Pill { width: 110; height: 44; rightCap: false; text: "Lock"; color: T.lilac; fam: s.fam; px: 18 }
                Pill { width: 110; height: 44; leftCap: false; rightCap: false; text: "Sleep"; color: T.lilac; fam: s.fam; px: 18 }
                Pill { width: 120; height: 44; leftCap: false; rightCap: false; text: "Log out…"; color: T.peach; fam: s.fam; px: 18 }
                Pill { width: 120; height: 44; leftCap: false; rightCap: false; text: "Restart…"; color: T.sunset; fam: s.fam; px: 18 }
                Pill { width: 140; height: 44; leftCap: false; text: "Shut down…"; color: T.alert; fam: s.fam; px: 18 }
            }
        }
    }
}
