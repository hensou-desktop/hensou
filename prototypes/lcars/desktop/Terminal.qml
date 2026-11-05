// PROTOTYPE — Ghostty with an LCARS palette. Colours only; Ghostty draws itself.
import QtQuick
import "../tokens.js" as T

Rectangle {
    id: term
    color: "#000000"
    clip: true
    Column {
        x: 14; y: 12; spacing: 3
        Repeater {
            model: [
                { c: T.lilac, t: "simon@myoko ~/code/github/hensou-desktop/hensou (spike/lcars-ui)" },
                { c: T.peach, t: "$ nix build --builders '' --max-jobs 1 .#hensou-demo" },
                { c: "#b3a597", t: "building '/nix/store/9x2k…-hensou-demo-0.1.0.drv'..." },
                { c: "#b3a597", t: "   Compiling hensou-qt-host v0.1.0" },
                { c: "#b3a597", t: "   Compiling hensou-demo v0.1.0" },
                { c: T.periwinkle, t: "    Finished `release` profile [optimized] target(s) in 41.07s" },
                { c: T.lilac, t: "simon@myoko ~/code/github/hensou-desktop/hensou (spike/lcars-ui)" },
                { c: T.peach, t: "$ ssh aka journalctl -u nix-daemon -n 3" },
                { c: "#b3a597", t: "Nov 05 21:44:02 aka nix-daemon[1123]: accepted connection from pid 88120" },
                { c: T.alert, t: "Nov 05 21:44:09 aka nix-daemon[1123]: warning: download buffer is full" },
                { c: "#b3a597", t: "Nov 05 21:46:51 aka nix-daemon[1123]: build finished" },
                { c: T.peach, t: "$ █" }
            ]
            delegate: Text { required property var modelData; text: modelData.t; color: modelData.c; font.family: "monospace"; font.pixelSize: 14 }
        }
    }
}
