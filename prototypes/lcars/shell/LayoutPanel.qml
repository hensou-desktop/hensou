// PROTOTYPE — Layout, grown out of its segment. Same content as PlatinumLayoutMenu:
// two tabs (this page, default), tiled or floating, windows per page, outer gap.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    property var screen
    readonly property var s: screen
    Panel {
        x: Math.min(s.segX("layout"), s.width - width - 8); y: s.f.topH
        width: 480; height: 470
        color: T.gold; fam: s.fam; title: "Layout"; code: "Super+O Y"
        Column {
            width: parent.width; spacing: 10
            Row {
                spacing: 4
                Pill { width: 150; height: 36; rightCap: false; text: "This page"; color: T.gold; fam: s.fam; px: 17 }
                Pill { width: 150; height: 36; leftCap: false; text: "Default"; color: T.dim; ink: T.peach; fam: s.fam; px: 17 }
            }
            Row {
                spacing: 4
                Pill { width: 150; height: 44; rightCap: false; leftCap: false; text: "Tiled"; sub: "Super+F"; color: T.lilac; active: true; fam: s.fam; px: 20 }
                Pill { width: 150; height: 44; leftCap: false; rightCap: false; text: "Floating"; color: T.dim; ink: T.peach; fam: s.fam; px: 20 }
            }
            Text { text: "WINDOWS PER PAGE"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Row {
                spacing: 4
                Repeater {
                    model: ["1", "2", "3"]
                    delegate: Pill { required property string modelData; required property int index; width: 70; height: 44; leftCap: index === 0; rightCap: index === 2; text: modelData; color: modelData === "3" ? T.gold : T.lilac; fam: s.fam; px: 24 }
                }
            }
            Text { text: "OUTER GAP"; color: T.gold; font.family: s.fam; font.pixelSize: 16 }
            Row {
                spacing: 12
                LevelBar { value: 0.25; blocks: 16; blockW: 14; blockH: 26; color: T.peach }
                Text { text: "8 px"; color: T.peach; font.family: s.fam; font.pixelSize: 26; anchors.verticalCenter: parent.verticalCenter }
            }
            Line { label: "Zen margins"; value: "Super+Shift+M"; tag: "zen"; fam: s.fam; color: T.lilac }
            Text { text: "New pages start with 3 windows and an 8 px gap."; color: T.peach; font.family: s.fam; font.pixelSize: 18 }
        }
    }
}
