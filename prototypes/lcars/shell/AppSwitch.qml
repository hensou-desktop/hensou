// PROTOTYPE — Super+Tab as a work-area takeover. The live shell cycles apps
// (app_cycle_step); the target app's windows list under it, never a page number.
import QtQuick
import "../tokens.js" as T
import ".."

Takeover {
    title: "Switch"; code: "Super+Tab"; color: T.sunset
    Column {
        spacing: 24
        Flow {
            width: parent.width; spacing: 6
            Repeater {
                model: [ { a: "Files", n: 1, c: T.lilac }, { a: "Chromium", n: 3, c: T.sunset, on: true }, { a: "Ghostty", n: 2, c: T.peach },
                         { a: "Pyxamp", n: 1, c: T.lilac }, { a: "Signal", n: 1, c: T.peach, hidden: true }, { a: "Zed", n: 1, c: T.sunset } ]
                delegate: Pill {
                    required property var modelData
                    width: 230; height: 140; leftCap: false; rightCap: false
                    text: modelData.a; sub: modelData.n + (modelData.n === 1 ? " window" : " windows") + (modelData.hidden ? ", hidden" : "")
                    color: modelData.on ? T.gold : modelData.hidden ? T.dim : modelData.c
                    ink: modelData.hidden ? T.peach : T.space
                    fam: s.fam; px: 36
                }
            }
        }
        Text { text: "CHROMIUM WINDOWS"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
        Column {
            width: 760; spacing: 4
            Line { label: "Window rules – Hyprland Wiki"; value: "this page"; tag: "1"; selected: true; fam: s.fam; color: T.sunset; px: 26 }
            Line { label: "Forgerie"; value: "beside Pyxamp"; tag: "2"; fam: s.fam; color: T.sunset; px: 26 }
            Line { label: "Jellyfin"; value: "portable monitor"; tag: "3"; fam: s.fam; color: T.sunset; px: 26 }
        }
    }
}
