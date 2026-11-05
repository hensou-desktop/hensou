// PROTOTYPE — Files inside the LCARS desktop. The desktop frame already shows the
// app and host, so Files drops its own elbow and shows only the path and the list.
import QtQuick
import "../tokens.js" as T
import "../plan.js" as Plan
import "../data.js" as Data
import ".."

Rectangle {
    id: f
    property string fam: ""
    color: T.space
    clip: true
    Text {
        x: 6; y: 2; width: parent.width - 12
        text: "home / simon / code / hensou"
        color: T.sunset; font.family: f.fam; font.pixelSize: 30; elide: Text.ElideLeft
    }
    FileList {
        x: 6; y: 46; width: parent.width - 12; height: parent.height - 46
        entries: Data.ideal; fam: f.fam; accent: T.lilac
        p: Plan.plan(width, 900, 0)
    }
}
