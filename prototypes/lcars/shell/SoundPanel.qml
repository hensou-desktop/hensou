// PROTOTYPE — Sound as a band (split screen). Same content as PlatinumSoundMenu:
// the level, mute, output and input devices.
import QtQuick
import "../tokens.js" as T
import ".."

Band {
    title: "Sound"; code: "Super+O S"; color: T.gold
    Row {
        spacing: 40
        Column {
            spacing: 12
            Text { text: "LEVEL"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Row {
                spacing: 14
                LevelBar { value: 0.4; blocks: 24; blockW: 12; blockH: 44; color: T.peach }
                Text { text: "40%"; color: T.peach; font.family: s.fam; font.pixelSize: 44; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 4
                Pill { width: 130; height: 44; rightCap: false; text: "Mute"; color: T.dim; ink: T.peach; fam: s.fam; px: 18 }
                Pill { width: 130; height: 44; leftCap: false; text: "Sounds…"; color: T.lilac; fam: s.fam; px: 18 }
            }
        }
        Column {
            width: 420; spacing: 4
            Text { text: "OUTPUT"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Speakers"; tag: "out"; value: "in use"; selected: true; fam: s.fam; color: T.peach }
            Line { label: "Galaxy Buds2 Pro"; tag: "bt"; value: "connected"; fam: s.fam; color: T.periwinkle }
            Line { label: "Portable monitor (HDMI)"; tag: "hdmi"; fam: s.fam; color: T.lilac }
        }
        Column {
            width: 360; spacing: 4
            Text { text: "INPUT"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Microphone array"; tag: "in"; value: "in use"; check: true; fam: s.fam; color: T.peach }
            Line { label: "Galaxy Buds2 Pro"; tag: "bt"; fam: s.fam; color: T.periwinkle }
        }
    }
}
