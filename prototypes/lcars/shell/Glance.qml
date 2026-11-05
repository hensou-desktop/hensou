// PROTOTYPE — the glance space (Super+W) as a work-area takeover: the screen
// becomes a fleet status display, Fleet and Disks side by side. No dither, no dim.
import QtQuick
import "../tokens.js" as T
import ".."

Takeover {
    title: "Glance"; code: "Super+W"; color: T.lilac
    Row {
        spacing: 50
        Column {
            width: 820; spacing: 4
            Text { text: "FLEET  8 HOSTS, 1 DOWN  SUPER+B"; color: T.lilac; font.family: s.fam; font.pixelSize: 18 }
            Row {
                Repeater {
                    model: [ { t: "HOST", w: 150 }, { t: "CPU", w: 220 }, { t: "MEMORY", w: 220 }, { t: "DISK", w: 220 } ]
                    delegate: Text { required property var modelData; width: modelData.w; text: modelData.t; color: T.lilac; font.family: s.fam; font.pixelSize: 15 }
                }
            }
            Repeater {
                model: [
                    { h: "kuro", down: true },
                    { h: "aka", cpu: 0.86, mem: 0.62, disk: 0.97, hot: true },
                    { h: "rakku", cpu: 0.12, mem: 0.48, disk: 0.71 },
                    { h: "myoko", cpu: 0.31, mem: 0.55, disk: 0.44 },
                    { h: "zao", cpu: 0.18, mem: 0.37, disk: 0.52 },
                    { h: "yari", cpu: 0.05, mem: 0.22, disk: 0.33 },
                    { h: "unzen", cpu: 0.41, mem: 0.30, disk: 0.28 },
                    { h: "tate", cpu: 0.02, mem: 0.15, disk: 0.12 }
                ]
                delegate: Row {
                    required property var modelData
                    height: 56
                    Pill { width: 140; height: 50; leftCap: false; rightCap: false; text: modelData.h; color: modelData.down ? T.alert : modelData.hot ? T.gold : T.lilac; fam: s.fam; px: 24 }
                    Item { width: 10; height: 1 }
                    Text { visible: !!modelData.down; text: "Not reporting for 14 min"; color: T.alert; font.family: s.fam; font.pixelSize: 26; anchors.verticalCenter: parent.verticalCenter }
                    Repeater {
                        model: modelData.down ? [] : [modelData.cpu, modelData.mem, modelData.disk]
                        delegate: Item {
                            required property real modelData
                            width: 220; height: 50
                            LevelBar { anchors.verticalCenter: parent.verticalCenter; value: parent.modelData; blocks: 14; blockW: 10; blockH: 26; color: parent.modelData > 0.9 ? T.alert : parent.modelData > 0.8 ? T.gold : T.periwinkle }
                            Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: Math.round(parent.modelData * 100); color: T.peach; font.family: s.fam; font.pixelSize: 22 }
                        }
                    }
                }
            }
        }
        Column {
            width: 560; spacing: 6
            Text { text: "DISKS  1 ISSUE  SUPER+O D"; color: T.sunset; font.family: s.fam; font.pixelSize: 18 }
            Line { label: "aka: /storage 97% full"; value: "high"; tag: "!"; color: T.alert; valueColor: T.alert; fam: s.fam; px: 24 }
            Line { label: "rakku: sdb reallocated sectors 8"; value: "watch"; tag: "?"; color: T.gold; valueColor: T.gold; fam: s.fam; px: 24 }
            Text { text: "Checked 21:40, 7 minutes ago."; color: T.peach; font.family: s.fam; font.pixelSize: 20 }
        }
    }
}
