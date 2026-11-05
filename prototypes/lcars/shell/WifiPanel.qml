// PROTOTYPE — Wi-Fi, grown out of its segment. Same content as PlatinumWifiMenu:
// networks by strength, the password field inline, a failure said in full.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    property var screen
    readonly property var s: screen
    Panel {
        x: Math.min(s.segX("wifi"), s.width - width - 8); y: s.f.topH
        width: 500; height: 520
        color: T.gold; fam: s.fam; title: "Wi-Fi"; code: "Super+O W"
        Column {
            width: parent.width; spacing: 6
            Row {
                spacing: 4
                Pill { width: 110; height: 36; rightCap: false; text: "Radio on"; color: T.periwinkle; fam: s.fam; px: 17 }
                Pill { width: 120; height: 36; leftCap: false; text: "Rescan"; color: T.lilac; fam: s.fam; px: 17 }
            }
            Line { label: "Mountain home"; tag: "5g"; value: "connected"; check: true; fam: s.fam; color: T.periwinkle }
            Line { label: "Mountain IoT"; tag: "2.4"; value: "▮▮▮▯"; fam: s.fam; color: T.lilac }
            Line { label: "Café Pinole"; tag: "5g"; value: "▮▮▮▯  secured"; selected: true; fam: s.fam; color: T.lilac }
            Rectangle {
                // The password row, inline under the chosen network.
                width: parent.width; height: 52; color: T.space
                Rectangle { x: 50; width: parent.width - 50 - 134; height: 44; y: 4; color: T.space; border.color: T.gold; border.width: 2; radius: 22
                    Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "••••••••"; color: T.peach; font.pixelSize: 20 } }
                Pill { x: parent.width - 130; y: 4; width: 130; height: 44; leftCap: false; text: "Connect"; color: T.gold; fam: s.fam; px: 18 }
            }
            Line { label: "xfinitywifi"; tag: "5g"; value: "▮▮▯▯  open"; fam: s.fam; color: T.lilac }
            Line { label: "DIRECT-roku-893"; tag: "2.4"; value: "▮▯▯▯"; fam: s.fam; color: T.lilac }
            Text { width: parent.width; wrapMode: Text.Wrap; text: "Last attempt failed: wrong password for Café Pinole."; color: T.alert; font.family: s.fam; font.pixelSize: 19 }
        }
    }
}
