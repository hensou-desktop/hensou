// PROTOTYPE — Layout as a band (split screen). Same content as PlatinumLayoutMenu.
import QtQuick
import "../tokens.js" as T
import ".."

Band {
    title: "Layout"; code: "Super+O Y"; color: T.gold
    Row {
        spacing: 40
        Column {
            spacing: 10
            Text { text: "EDITS"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Pill { width: 170; height: 44; rightCap: false; text: "This page"; color: T.gold; fam: s.fam; px: 18 }
            Pill { width: 170; height: 44; rightCap: false; text: "Default"; color: T.dim; ink: T.peach; fam: s.fam; px: 18 }
        }
        Column {
            spacing: 10
            Text { text: "ARRANGE"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Row {
                spacing: 4
                Pill { width: 150; height: 44; rightCap: false; text: "Tiled"; sub: "Super+F"; color: T.lilac; active: true; fam: s.fam; px: 20 }
                Pill { width: 150; height: 44; leftCap: false; text: "Floating"; color: T.dim; ink: T.peach; fam: s.fam; px: 20 }
            }
            Text { text: "WINDOWS PER PAGE  SUPER+1 2 3"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Row {
                spacing: 4
                Repeater {
                    model: ["1", "2", "3"]
                    delegate: Pill { required property string modelData; required property int index; width: 80; height: 44; leftCap: index === 0; rightCap: index === 2; text: modelData; color: modelData === "3" ? T.gold : T.lilac; fam: s.fam; px: 24 }
                }
            }
        }
        Column {
            spacing: 10
            Text { text: "OUTER GAP  SUPER+SHIFT+[ ]"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Row {
                spacing: 12
                LevelBar { value: 0.25; blocks: 16; blockW: 14; blockH: 34; color: T.peach }
                Text { text: "8 px"; color: T.peach; font.family: s.fam; font.pixelSize: 32; anchors.verticalCenter: parent.verticalCenter }
            }
            Line { width: 420; label: "Zen margins"; value: "Super+Shift+M"; tag: "zen"; fam: s.fam; color: T.lilac }
            Text { text: "New pages start with 3 windows and an 8 px gap."; color: T.peach; font.family: s.fam; font.pixelSize: 18 }
        }
    }
}
