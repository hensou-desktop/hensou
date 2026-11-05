// PROTOTYPE — Wi-Fi as a band (split screen): networks in two columns, the
// password row inline under the chosen one, the last failure said in full.
import QtQuick
import "../tokens.js" as T
import ".."

Band {
    title: "Wi-Fi"; code: "Super+O W"; color: T.gold
    Row {
        spacing: 32
        Column {
            spacing: 6
            Row {
                spacing: 4
                Pill { width: 130; height: 40; rightCap: false; text: "Radio on"; color: T.periwinkle; fam: s.fam; px: 17 }
                Pill { width: 130; height: 40; leftCap: false; text: "Rescan"; color: T.lilac; fam: s.fam; px: 17 }
            }
            Text { width: 270; wrapMode: Text.Wrap; text: "Last attempt failed: wrong password for Café Pinole."; color: T.alert; font.family: s.fam; font.pixelSize: 20 }
        }
        Column {
            width: 520; spacing: 4
            Line { label: "Mountain home"; tag: "5g"; value: "connected"; check: true; fam: s.fam; color: T.periwinkle }
            Line { label: "Café Pinole"; tag: "5g"; value: "▮▮▮▯  secured"; selected: true; fam: s.fam; color: T.lilac }
            Item {
                width: parent.width; height: 50
                Rectangle { x: 50; y: 3; width: parent.width - 50 - 134; height: 44; color: T.space; border.color: T.gold; border.width: 2; radius: 22
                    Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "••••••••"; color: T.peach; font.pixelSize: 20 } }
                Pill { x: parent.width - 130; y: 3; width: 130; height: 44; leftCap: false; text: "Connect"; color: T.gold; fam: s.fam; px: 18 }
            }
            Line { label: "Mountain IoT"; tag: "2.4"; value: "▮▮▮▯"; fam: s.fam; color: T.lilac }
        }
        Column {
            width: 380; spacing: 4
            Line { label: "xfinitywifi"; tag: "5g"; value: "▮▮▯▯  open"; fam: s.fam; color: T.lilac }
            Line { label: "DIRECT-roku-893"; tag: "2.4"; value: "▮▯▯▯"; fam: s.fam; color: T.lilac }
            Line { label: "Hidden network…"; tag: "+"; fam: s.fam; color: T.dim }
        }
    }
}
