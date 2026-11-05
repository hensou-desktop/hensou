// PROTOTYPE — the session confirmation (menu-models.js alert()). Cancel is the
// default; the destructive action is the far end, in alert red.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    property var screen
    readonly property var s: screen
    anchors.fill: parent
    Rectangle { x: s.f.work.x; y: s.f.work.y; width: s.f.work.w; height: s.f.work.h; color: "#c8000000" }
    Panel {
        width: 620; height: 300
        x: s.f.work.x + (s.f.work.w - width) / 2; y: s.f.work.y + (s.f.work.h - height) / 2
        color: T.alert; fam: s.fam; title: "Shut down"; code: "Esc cancels"
        Column {
            width: parent.width; spacing: 18
            Text { width: parent.width; wrapMode: Text.Wrap; text: "Are you sure you want to shut down Myoko? Open windows close without saving."; color: T.peach; font.family: s.fam; font.pixelSize: 26 }
            Text { text: "6 windows are open. Ghostty is running nix build."; color: T.gold; font.family: s.fam; font.pixelSize: 20 }
            Row {
                spacing: 4
                Pill { width: 180; height: 50; rightCap: false; text: "Cancel"; sub: "Default"; color: T.gold; fam: s.fam; px: 22 }
                Pill { width: 200; height: 50; leftCap: false; text: "Shut down"; color: T.alert; fam: s.fam; px: 22 }
            }
        }
    }
}
