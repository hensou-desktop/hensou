// PROTOTYPE — a Chromium window with no title bar. The page keeps the site's own
// colours and body face; the theme reaches only scroll bars and form controls
// (modules/quickshell/themes/<id>/web.css in Mountainous).
import QtQuick
import "../tokens.js" as T

Rectangle {
    id: page
    property string fam: ""
    property bool themed: true   // false: the web theme is postponed, pages are untouched
    color: "#ffffff"
    clip: true

    Rectangle {
        // The site's own header.
        width: parent.width; height: 56; color: "#1f2328"
        Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: "Hyprland Wiki"; color: "#ffffff"; font.pixelSize: 20; font.bold: true }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            Repeater { model: ["Getting started", "Configuring", "Plugins", "FAQ"]; delegate: Text { required property string modelData; text: modelData; color: "#d0d7de"; font.pixelSize: 15 } }
        }
    }
    Column {
        x: 40; y: 88; width: Math.min(720, parent.width - 80); spacing: 14
        Text { text: "Window rules"; font.pixelSize: 34; font.bold: true; color: "#1f2328" }
        Text {
            width: parent.width; wrapMode: Text.Wrap; color: "#31363b"; font.pixelSize: 16; lineHeight: 1.35
            text: "Window rules let you set per-window behaviour: where a window opens, its size, whether it floats, and its border. Rules match on class, title, workspace and more. A rule set in the config applies to every new window that matches it."
        }
        Text { text: "Search the rules"; font.pixelSize: 15; color: "#31363b" }
        Row {
            spacing: 8
            // Form controls: the part web.css themes. Pill field and pill button.
            Rectangle {
                width: 300; height: 36; radius: page.themed ? 18 : 4; color: page.themed ? "#000000" : "#ffffff"; border.color: page.themed ? T.lilac : "#8c959f"; border.width: page.themed ? 2 : 1
                Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "noborder"; color: page.themed ? T.peach : "#1f2328"; font.family: page.themed ? page.fam : "sans-serif"; font.pixelSize: page.themed ? 18 : 15 }
            }
            Rectangle {
                width: 110; height: 36; color: page.themed ? T.sunset : "#1f883d"; topRightRadius: page.themed ? 18 : 6; bottomRightRadius: page.themed ? 18 : 6; topLeftRadius: page.themed ? 0 : 6; bottomLeftRadius: page.themed ? 0 : 6
                Text { anchors.right: parent.right; anchors.rightMargin: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: page.themed ? "SEARCH" : "Search"; color: page.themed ? T.space : "#ffffff"; font.family: page.themed ? page.fam : "sans-serif"; font.pixelSize: page.themed ? 17 : 15 }
            }
        }
        Rectangle {
            width: parent.width; height: 150; color: "#f6f8fa"; radius: 6; border.color: "#d0d7de"
            Text {
                x: 16; y: 14; color: "#1f2328"; font.family: "monospace"; font.pixelSize: 14; lineHeight: 1.4
                text: "windowrule = noborder, class:^(chromium)$\nwindowrule = float, title:^(Picture in picture)$\nwindowrule = workspace 2, class:^(com.mitchellh.ghostty)$"
            }
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap; color: "#31363b"; font.pixelSize: 16; lineHeight: 1.35
            text: "Rules are evaluated top to bottom. When two rules set the same property, the last one wins. Use hyprctl clients to see the class and title of an open window."
        }
    }
    // LCARS scroll bar from web.css.
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 3; y: 60; width: 10; height: parent.height - 66; radius: 5; color: "#e9e1d8"
        Rectangle { width: 10; height: parent.height * 0.3; y: parent.height * 0.08; radius: 5; color: page.themed ? T.sunset : "#8c959f" }
    }
}
