// PROTOTYPE — the system menu as a work-area takeover. Same rows as
// menu-models.js apple() and Win98's Start menu, laid out as an LCARS screen.
import QtQuick
import "../tokens.js" as T
import ".."

Takeover {
    title: "Myoko"; code: "the elbow"; color: T.gold
    Row {
        spacing: 50
        Column {
            width: 420; spacing: 14
            Text { text: "THIS COMPUTER"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Grid {
                columns: 2; columnSpacing: 30; rowSpacing: 8
                Repeater {
                    model: [ { k: "NixOS", v: "25.11" }, { k: "Generation", v: "system-61" }, { k: "Uptime", v: "3 d 4 h" }, { k: "Revision", v: "8c22538" } ]
                    delegate: Column {
                        required property var modelData
                        Text { text: modelData.k.toUpperCase(); color: T.lilac; font.family: s.fam; font.pixelSize: 14 }
                        Text { text: modelData.v; color: T.peach; font.family: s.fam; font.pixelSize: 34 }
                    }
                }
            }
            Text { text: "SESSION"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Column {
                spacing: 4
                Pill { width: 260; height: 52; leftCap: false; text: "Lock"; sub: "Super+Esc"; color: T.lilac; fam: s.fam; px: 22 }
                Pill { width: 260; height: 52; leftCap: false; text: "Sleep"; color: T.lilac; fam: s.fam; px: 22 }
                Pill { width: 260; height: 52; leftCap: false; text: "Log out"; sub: "Super+Shift+E"; color: T.peach; fam: s.fam; px: 22 }
                Pill { width: 260; height: 52; leftCap: false; text: "Restart"; color: T.sunset; fam: s.fam; px: 22 }
                Pill { width: 260; height: 52; leftCap: false; text: "Shut down"; color: T.alert; fam: s.fam; px: 22 }
            }
        }
        Column {
            width: 420; spacing: 6
            Text { text: "CONTROL PANELS"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Repeater {
                model: [ { t: "Appearance", c: T.sunset, k: "Super+D toggles" }, { t: "Bluetooth", c: T.periwinkle, k: "Super+O B" }, { t: "Brightness", c: T.peach, k: "Super+O L" },
                         { t: "Remote builds", c: T.lilac, k: "Super+O R" }, { t: "Sound", c: T.peach, k: "Super+O S" }, { t: "Wi-Fi", c: T.periwinkle, k: "Super+O W" } ]
                delegate: Line { required property var modelData; label: modelData.t; value: modelData.k; tag: ""; color: modelData.c; fam: s.fam }
            }
        }
        Column {
            width: 460; spacing: 6
            Text { text: "RECENT APPLICATIONS"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Ghostty"; tag: "app"; fam: s.fam; color: T.peach }
            Line { label: "Files"; tag: "app"; fam: s.fam; color: T.lilac; selected: true }
            Line { label: "Zed"; tag: "app"; fam: s.fam; color: T.sunset }
            Text { text: "WEB APPS"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Forgerie"; tag: "web"; fam: s.fam; color: T.sunset }
            Line { label: "Jellyfin"; tag: "web"; fam: s.fam; color: T.sunset }
            Line { label: "Find…"; value: "Super+P"; tag: "?"; fam: s.fam; color: T.periwinkle }
        }
    }
}
