// PROTOTYPE — a message inside the arm. The comms block grows taller in place,
// under the window list; it never crosses into the work area. Long messages
// open Comms as a takeover. Critical also turns the frame red.
import QtQuick
import "../tokens.js" as T
import ".."

Item {
    id: c
    property var screen
    readonly property var s: screen
    readonly property bool critical: s.critical
    readonly property color col: critical ? T.alert : T.periwinkle
    readonly property real y0: s.armBottom + 4
    readonly property real w: s.f.armW
    Rectangle { x: 0; y: c.y0; width: c.w; height: 340; color: c.col }
    Rectangle { x: 0; y: c.y0 + 340; width: c.w; height: 4; color: T.space }
    Column {
        x: 12; y: c.y0 + 8; width: c.w - 24; spacing: 4
        Text { anchors.right: parent.right; text: (c.critical ? "Alert 1 of 2" : "Comms 1 of 2").toUpperCase(); color: T.space; font.family: s.fam; font.pixelSize: 15 }
        Text { anchors.right: parent.right; text: c.critical ? "FROM AKA, 21:46" : "SIGNAL, 21:46"; color: T.space; font.family: s.fam; font.pixelSize: 15 }
        Text { width: parent.width; horizontalAlignment: Text.AlignRight; wrapMode: Text.Wrap; text: c.critical ? "Storage almost full" : "Laure"; color: T.space; font.family: s.fam; font.pixelSize: 32; font.weight: Font.Medium }
        Text { width: parent.width; horizontalAlignment: Text.AlignRight; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
            text: c.critical ? "/storage on aka is 97% full. Builds will stop at 100%." : "Are you still up for dinner at 7? I can pick up the bread."
            color: T.space; font.family: s.fam; font.pixelSize: 19 }
    }
    Column {
        x: 12; y: c.y0 + 340 - 104; width: c.w - 24; spacing: 4
        Pill { width: parent.width; height: 48; leftCap: false; text: c.critical ? "Open storage" : "Reply"; color: T.space; ink: c.col; fam: s.fam; px: 19 }
        Pill { width: parent.width; height: 48; leftCap: false; text: c.critical ? "Acknowledge" : "Dismiss"; color: T.space; ink: c.col; fam: s.fam; px: 19 }
    }
}
