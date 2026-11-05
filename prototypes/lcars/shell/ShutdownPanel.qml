// PROTOTYPE — the session confirmation as a work-area takeover in alert red.
// Cancel is the default and the first block; Shut down sits at the far end.
import QtQuick
import "../tokens.js" as T
import ".."

Takeover {
    title: "Shut down"; code: "Esc cancels"; color: T.alert
    Column {
        y: 120; spacing: 26
        Text { width: 1100; wrapMode: Text.Wrap; text: "Shut down Myoko? Open windows close without saving."; color: T.peach; font.family: s.fam; font.pixelSize: 54 }
        Text { text: "6 windows are open. Ghostty is running nix build."; color: T.gold; font.family: s.fam; font.pixelSize: 28 }
        Row {
            spacing: 6
            Pill { width: 260; height: 80; rightCap: false; text: "Cancel"; sub: "Default"; color: T.gold; fam: s.fam; px: 30 }
            Pill { width: 300; height: 80; leftCap: false; text: "Shut down"; color: T.alert; fam: s.fam; px: 30 }
        }
    }
}
