// PROTOTYPE — Super+Tab: the live shell cycles apps, not windows (app_cycle_step),
// like the Application menu. A band across the work area: apps most recent
// first, the target gold, its windows listed under it with where they are.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    property var screen
    readonly property var s: screen
    anchors.fill: parent
    Rectangle { x: s.f.work.x; y: s.f.work.y; width: s.f.work.w; height: s.f.work.h; color: "#c8000000" }
    Item {
        width: s.f.work.w - 80; height: 330
        x: s.f.work.x + 40; y: s.f.work.y + (s.f.work.h - height) / 2
        Rectangle { anchors.fill: parent; color: T.space }
        Rectangle { width: parent.width; height: 26; color: T.sunset; topLeftRadius: 13; topRightRadius: 13
            Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.bottom: parent.bottom; text: "SWITCH APP  SUPER+TAB"; color: T.space; font.family: s.fam; font.pixelSize: 20 } }
        Row {
            x: 0; y: 34; spacing: 4
            Repeater {
                model: [ { a: "Files", n: 1, c: T.lilac }, { a: "Chromium", n: 3, c: T.sunset, on: true }, { a: "Ghostty", n: 2, c: T.peach },
                         { a: "Pyxamp", n: 1, c: T.lilac }, { a: "Signal", n: 1, c: T.peach, hidden: true }, { a: "Zed", n: 1, c: T.sunset } ]
                delegate: Pill {
                    required property var modelData
                    width: 180; height: 110; leftCap: false; rightCap: false
                    text: modelData.a; sub: modelData.n + (modelData.n === 1 ? " window" : " windows") + (modelData.hidden ? ", hidden" : "")
                    color: modelData.on ? T.gold : modelData.hidden ? T.dim : modelData.c
                    ink: modelData.hidden ? T.peach : T.space
                    fam: s.fam; px: 30
                }
            }
        }
        Column {
            x: 184; y: 156; width: 560; spacing: 2
            Line { label: "Window rules – Hyprland Wiki"; tag: "1"; selected: true; fam: s.fam; color: T.sunset }
            Line { label: "Forgerie"; value: "beside Pyxamp"; tag: "2"; fam: s.fam; color: T.sunset }
            Line { label: "Jellyfin"; value: "external screen"; tag: "3"; fam: s.fam; color: T.sunset }
        }
        Rectangle { y: parent.height - 14; width: parent.width; height: 14; color: T.lilac; bottomLeftRadius: 7; bottomRightRadius: 7 }
    }
}
