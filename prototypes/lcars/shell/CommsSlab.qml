// PROTOTYPE — a message out of the arm (pass 3), positioned under the window list.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    id: slab
    property var screen
    readonly property var s: screen
    readonly property bool critical: s.critical
    readonly property color c: critical ? T.alert : T.periwinkle
    readonly property real h: 196
    readonly property real extW: 660
    // Directly under the window list, where the folded comms block sits.
    readonly property real y0: s.armBottom + 4
    Rectangle { x: 0; y: slab.y0; width: s.f.armW + slab.extW; height: slab.h; color: slab.c; topRightRadius: 44; bottomRightRadius: 44 }
    Rectangle { x: 0; y: slab.y0 + slab.h; width: s.f.armW; height: 4; color: T.space }
    Text { x: s.f.armW - width - 12; y: slab.y0 + 6; text: slab.critical ? "ALERT" : "COMMS"; color: T.space; font.family: s.fam; font.pixelSize: 15 }
    Text { x: s.f.armW - width - 12; y: slab.y0 + 24; text: "1 OF 2"; color: T.space; font.family: s.fam; font.pixelSize: 26 }
    Rectangle { x: s.f.armW + 8; y: slab.y0 + 14; width: 4; height: slab.h - 28; color: T.space }
    Column {
        x: s.f.armW + 28; y: slab.y0 + 12; width: slab.extW - 80; spacing: 4
        Text { text: slab.critical ? "FROM AKA, 21:46" : "FROM SIGNAL, 21:46"; color: T.space; font.family: s.fam; font.pixelSize: 16 }
        Text { text: slab.critical ? "Storage almost full" : "Laure"; color: T.space; font.family: s.fam; font.pixelSize: 40; font.weight: Font.Medium }
        Text { width: parent.width; wrapMode: Text.Wrap; text: slab.critical ? "/storage on aka is 97% full. Builds will stop at 100%." : "Are you still up for dinner at 7? I can pick up the bread."; color: T.space; font.family: s.fam; font.pixelSize: 21 }
    }
    Row {
        x: s.f.armW + 28; y: slab.y0 + slab.h - 52; spacing: 4
        Pill { width: 170; height: 40; text: slab.critical ? "Open storage" : "Reply"; color: T.space; ink: slab.c; rightCap: false; fam: s.fam; px: 18 }
        Pill { width: 150; height: 40; text: slab.critical ? "Acknowledge" : "Dismiss"; color: T.space; ink: slab.c; leftCap: false; fam: s.fam; px: 18 }
    }
}
