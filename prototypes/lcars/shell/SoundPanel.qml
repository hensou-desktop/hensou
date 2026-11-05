// PROTOTYPE — Sound, grown out of the Vol segment. Same content as
// PlatinumSoundMenu: the level on the slider row, output and input devices.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    property var screen
    readonly property var s: screen
    Panel {
        x: Math.min(s.segX("vol"), s.width - width - 8); y: s.f.topH
        width: 460; height: 470
        color: T.gold; fam: s.fam; title: "Sound"; code: "Super+O S"
        Column {
            width: parent.width; spacing: 8
            Row {
                spacing: 14
                LevelBar { value: 0.4; blocks: 24; blockW: 11; blockH: 30; color: T.peach }
                Text { text: "40%"; color: T.peach; font.family: s.fam; font.pixelSize: 32; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 4
                Pill { width: 120; height: 36; rightCap: false; text: "Mute"; color: T.dim; ink: T.peach; fam: s.fam; px: 17 }
                Pill { width: 120; height: 36; leftCap: false; text: "Sounds…"; color: T.lilac; fam: s.fam; px: 17 }
            }
            Text { text: "OUTPUT"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Speakers"; tag: "out"; value: "in use"; selected: true; fam: s.fam; color: T.peach }
            Line { label: "Galaxy Buds2 Pro"; tag: "bt"; value: "connected"; fam: s.fam; color: T.periwinkle }
            Line { label: "Portable monitor (HDMI)"; tag: "hdmi"; fam: s.fam; color: T.lilac }
            Text { text: "INPUT"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Line { label: "Microphone array"; tag: "in"; value: "in use"; check: true; fam: s.fam; color: T.peach }
        }
    }
    // The 1.5 s level tag (PlatinumBarHelp) is the segment itself: it shows the number.
}
