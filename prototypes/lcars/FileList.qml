// PROTOTYPE — LCARS file list. Names keep their real case: file names are case-sensitive,
// so only chrome is upper case.
import QtQuick
import "tokens.js" as T

Item {
    id: list
    property var entries: []
    property var p
    property string fam: ""
    property int selected: 1
    property color accent: T.lilac
    clip: true

    function kindColor(k) {
        if (k === "dir") return T.lilac;
        if (k === "link") return T.alert;
        if (k === "jpeg") return T.periwinkle;
        return T.sunset;
    }

    // Column header: thin bars, labels in the bar's own colour.
    Row {
        id: head
        spacing: T.gap
        height: list.p.short ? 0 : 22
        visible: !list.p.short
        width: parent.width
        Repeater {
            model: [
                { t: "Name", w: list.nameW(), c: list.accent },
                { t: "Size", w: list.p.showSize ? 110 : -1, c: T.peach },
                { t: "Modified", w: list.p.showDate ? 130 : -1, c: T.peach },
                { t: "Kind", w: list.p.showKind ? 80 : -1, c: T.peach }
            ]
            delegate: Item {
                visible: modelData.w > 0
                width: Math.max(0, modelData.w); height: 22
                Rectangle { width: parent.width; height: 6; color: modelData.c; anchors.bottom: parent.bottom }
                Text {
                    text: modelData.t.toUpperCase(); color: modelData.c
                    font.family: list.fam; font.pixelSize: 14
                    anchors.right: parent.right; anchors.rightMargin: 2; anchors.bottom: parent.bottom; anchors.bottomMargin: 7
                }
            }
        }
    }

    function nameW() {
        var w = list.width - 56; // 10 px kept for the scroll bar
        if (p.showSize) w -= 110 + T.gap;
        if (p.showDate) w -= 130 + T.gap;
        if (p.showKind) w -= 80 + T.gap;
        return w;
    }

    ListView {
        id: lv
        anchors.top: head.bottom; anchors.topMargin: 6
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        model: list.entries
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool sel: index === list.selected
            width: lv.width
            height: list.p.rowPx + 12
            Row {
                spacing: T.gap
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: 42; height: row.height - 4
                    radius: height / 2
                    topRightRadius: 0; bottomRightRadius: 0
                    color: list.kindColor(row.modelData.kind)
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                        text: (row.modelData.kind === "dir" ? "DIR" : (row.modelData.kind || "—")).toUpperCase().slice(0, 4)
                        font.family: list.fam; font.pixelSize: 12; color: T.space
                    }
                }
                Rectangle {
                    width: list.nameW(); height: row.height - 4
                    color: row.sel ? T.gold : "transparent"
                    Text {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: row.modelData.name
                        color: row.sel ? T.space : (row.modelData.kind === "dir" ? T.lilac : T.peach)
                        font.family: list.fam; font.pixelSize: list.p.rowPx
                        elide: Text.ElideMiddle
                    }
                }
                Text {
                    visible: list.p.showSize; width: 110; height: row.height - 4
                    horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                    text: row.modelData.size; font.family: list.fam; font.pixelSize: list.p.rowPx - 2
                    color: row.modelData.size === "Unknown" ? T.alert : T.periwinkle
                }
                Text {
                    visible: list.p.showDate; width: 130; height: row.height - 4
                    horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                    text: row.modelData.date; font.family: list.fam; font.pixelSize: list.p.rowPx - 2
                    color: row.modelData.date === "Unknown" ? T.alert : T.peach
                }
                Text {
                    visible: list.p.showKind; width: 80; height: row.height - 4
                    horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                    text: row.modelData.kind === "dir" ? "Folder" : (row.modelData.kind ? row.modelData.kind.toUpperCase() + " file" : "File")
                    font.family: list.fam; font.pixelSize: list.p.rowPx - 2; color: T.peach
                }
            }
            MouseArea { anchors.fill: parent; onClicked: list.selected = row.index }
        }
    }

    // Scroll indicator: an LCARS bar segment on the right edge.
    Rectangle {
        visible: lv.contentHeight > lv.height
        anchors.right: parent.right; anchors.top: lv.top
        width: 4; height: lv.height; color: T.dim
        Rectangle {
            width: 4; color: list.accent
            height: Math.max(24, parent.height * lv.height / Math.max(1, lv.contentHeight))
            y: (parent.height - height) * (lv.contentY / Math.max(1, lv.contentHeight - lv.height))
        }
    }

    // Empty state: say what is here and offer the next action.
    Column {
        visible: list.entries.length === 0
        anchors.centerIn: parent
        spacing: 12
        Text { text: "This folder is empty"; color: T.peach; font.family: list.fam; font.pixelSize: 32; anchors.horizontalCenter: parent.horizontalCenter }
        Row {
            spacing: T.gap; anchors.horizontalCenter: parent.horizontalCenter
            Pill { width: 140; height: 40; text: "New folder"; fam: list.fam; color: T.lilac; rightCap: false }
            Pill { width: 140; height: 40; text: "Paste"; fam: list.fam; color: T.dim; ink: T.peach; leftCap: false }
        }
    }
}
