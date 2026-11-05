// PROTOTYPE — what an extension's content script could do to an article page:
// pull the text out (Readability-style) and re-set it as an LCARS reading view.
// Only for pages that opt in (reader key); app-like sites keep their own UI.
import QtQuick
import "../tokens.js" as T
import ".."

Rectangle {
    id: r
    property string fam: ""
    color: T.space
    clip: true

    // Contents built from the page's own headings.
    Column {
        x: 0; y: 16; width: 200; spacing: 4
        Pill { width: 200; height: 30; leftCap: false; text: "Contents"; color: T.sunset; fam: r.fam; px: 16 }
        Repeater {
            model: [ { t: "Window rules", on: true }, { t: "Syntax" }, { t: "Rules" }, { t: "Dynamic rules" }, { t: "Layer rules" } ]
            delegate: Pill {
                required property var modelData
                width: 200; height: 40; leftCap: false
                text: modelData.t; color: modelData.on ? T.gold : T.lilac; fam: r.fam; px: 17
            }
        }
        Rectangle { width: 200; height: 220; color: T.lilac; bottomRightRadius: 20 }
    }
    Column {
        x: 236; y: 16; width: Math.min(640, r.width - 280); spacing: 16
        Text { text: "Window rules"; color: T.sunset; font.family: r.fam; font.pixelSize: 56; font.weight: Font.Medium }
        Text {
            width: parent.width; wrapMode: Text.Wrap; color: T.peach; font.pixelSize: 18; lineHeight: 1.45
            text: "Window rules let you set per-window behaviour: where a window opens, its size, whether it floats, and its border. Rules match on class, title, workspace and more. A rule set in the config applies to every new window that matches it."
        }
        Rectangle {
            width: parent.width; height: 120; color: T.space; border.color: T.periwinkle; border.width: 2
            Rectangle { width: 120; height: 24; color: T.periwinkle; Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.bottom: parent.bottom; text: "CONFIG"; font.family: r.fam; font.pixelSize: 16; color: T.space } }
            Text {
                x: 16; y: 36; color: T.periwinkle; font.family: "monospace"; font.pixelSize: 15; lineHeight: 1.4
                text: "windowrule = noborder, class:^(chromium)$\nwindowrule = float, title:^(Picture in picture)$"
            }
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap; color: T.peach; font.pixelSize: 18; lineHeight: 1.45; textFormat: Text.StyledText
            text: "Rules are evaluated top to bottom. When two rules set the same property, the last one wins. Use <font color='#9999FF'><u>hyprctl clients</u></font> to see the class and title of an open window."
        }
    }
    // Reading progress, as an LCARS level bar on the right edge.
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 4; y: 16; width: 12; height: parent.height - 32; color: T.dim
        Rectangle { width: 12; height: parent.height * 0.22; color: T.sunset }
    }
}
