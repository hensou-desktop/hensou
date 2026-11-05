// PROTOTYPE — the glance space (Super+W) with its widgets: Fleet (Beszel hosts)
// and Disks (storage health). The work area recedes; the frame stays live and
// the Fleet segment is the glance menu's title (lit gold).
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    property var screen
    readonly property var s: screen
    anchors.fill: parent
    Rectangle { x: s.f.work.x; y: s.f.work.y; width: s.f.work.w; height: s.f.work.h; color: "#e0000000" }
    // A faint LCARS grid over the receded work: the glance space's dither.
    Repeater {
        model: Math.floor(s.f.work.h / 40)
        delegate: Rectangle { required property int index; x: s.f.work.x; y: s.f.work.y + index * 40; width: s.f.work.w; height: 1; color: "#2a2a44" }
    }
    Panel {
        x: s.f.work.x + s.f.work.w - width - 10; y: s.f.work.y + 10
        width: 760; height: 560
        color: T.lilac; fam: s.fam; title: "Fleet  8 hosts, 1 down"; code: "Super+B"
        Column {
            width: parent.width; spacing: 3
            Row {
                spacing: 0
                Repeater {
                    model: [ { t: "HOST", w: 130 }, { t: "CPU", w: 175 }, { t: "MEMORY", w: 175 }, { t: "DISK", w: 175 } ]
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
                    spacing: 0; height: 44
                    Pill { width: 120; height: 40; leftCap: true; rightCap: false; text: modelData.h; color: modelData.down ? T.alert : modelData.hot ? T.gold : T.lilac; fam: s.fam; px: 20 }
                    Item { width: 10; height: 1 }
                    Text { visible: !!modelData.down; text: "Not reporting for 14 min"; color: T.alert; font.family: s.fam; font.pixelSize: 22; anchors.verticalCenter: parent.verticalCenter }
                    Repeater {
                        model: modelData.down ? [] : [modelData.cpu, modelData.mem, modelData.disk]
                        delegate: Item {
                            required property real modelData
                            width: 175; height: 40
                            LevelBar { anchors.verticalCenter: parent.verticalCenter; value: parent.modelData; blocks: 12; blockW: 9; blockH: 20; color: parent.modelData > 0.9 ? T.alert : parent.modelData > 0.8 ? T.gold : T.periwinkle }
                            Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: Math.round(parent.modelData * 100); color: T.peach; font.family: s.fam; font.pixelSize: 18 }
                        }
                    }
                }
            }
        }
    }
    Panel {
        x: s.f.work.x + s.f.work.w - 760 - 10; y: s.f.work.y + 590
        width: 760; height: 250
        color: T.sunset; fam: s.fam; title: "Disks  1 issue"; code: "Super+O D"
        Column {
            width: parent.width; spacing: 4
            Line { label: "aka: /storage 97% full"; value: "high"; tag: "!"; color: T.alert; valueColor: T.alert; fam: s.fam }
            Line { label: "rakku: sdb SMART reallocated sectors 8"; value: "watch"; tag: "?"; color: T.gold; valueColor: T.gold; fam: s.fam }
            Text { text: "Checked 21:40, 7 minutes ago."; color: T.peach; font.family: s.fam; font.pixelSize: 18 }
        }
    }
}
