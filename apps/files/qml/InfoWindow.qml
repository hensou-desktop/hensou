import QtQuick
import Hensou
import Hensou.Host
import "Model.js" as Model

// Get Info (Platinum) or Properties (Memphis): name, kind, size, where,
// modified date, owner and permissions. Only the name can change. Locked
// (Platinum) and Read-only (Memphis) show the write bits; they are not
// editable here. Unknown values read "Unknown", never 0.
Window {
    id: root
    required property var app
    required property var entry
    readonly property bool win98: Theme.name === "win98"
    readonly property string theme: win98 ? "win98" : "platinum"
    readonly property real u: 2 / Math.max(0.5, metrics.devicePixelRatio)
    readonly property string entryKey: Model.key(entry.location)
    readonly property var live: app.store.state.info[entryKey] || entry
    readonly property string shownName: Model.entryName(live, theme)
    readonly property bool renamable: ["file", "folder", "alias", "launcher"].indexOf(live.kind) >= 0
        && !Model.isVirtual(live.location) && Model.placeType(live.location) !== "trash"
    property string draft: shownName
    property string problem: ""

    title: win98 ? shownName + " Properties" : shownName + " Info"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: win98 ? Win98Tokens.face : PlatinumTokens.menuSurface
    width: win98 ? 300 * u : 340
    readonly property real wantedHeight: Math.max(200, frame.item ? Math.ceil(frame.item.implicitHeight) : 380)
    height: wantedHeight
    // As in AlertWindow: fit the content again once the scale settles.
    onHeightChanged: if (height < wantedHeight - 0.5) refit.restart()
    onWantedHeightChanged: if (Math.abs(height - wantedHeight) > 0.5) refit.restart()
    property int refits: 0
    Timer {
        id: refit
        interval: 50
        // A compositor that keeps another size wins after a few tries.
        onTriggered: if (root.refits++ < 8) { root.height = root.wantedHeight; root.height = Qt.binding(function() { return root.wantedHeight; }); }
    }
    minimumWidth: win98 ? 200 * u : 240
    minimumHeight: 160

    function focusName() { Qt.callLater(function() { if (frame.item) frame.item.focusName(); }); }
    function rename() {
        const next = draft.trim();
        problem = "";
        if (!renamable || next === "" || next === live.name) return true;
        if (next.indexOf("/") >= 0) { problem = "A name cannot contain \u201c/\u201d."; return false; }
        app.store.send({ command: "rename", location: live.location, new_name: next }, function(event) {
            if (event.event === "error") root.problem = Model.errorText(event.error);
        });
        return true;
    }
    readonly property var rows: {
        const where = Model.parent(live.location);
        const out = [
            [win98 ? "Type:" : "Kind:", Model.kindText(live, theme)],
            [win98 ? "Location:" : "Where:", where ? Model.addressText(where, theme, app.hostname) : Model.locationName(live.location, theme, app.hostname)],
            ["Size:", Model.sizeInfo(live.size, theme)]
        ];
        if (live.kind === "alias") out.push([win98 ? "Target:" : "Original:", live.link_target || "Unknown"]);
        out.push([win98 ? "Modified:" : "Modified:", Model.dateText(live.modified, theme, "info")]);
        out.push(["Owner:", live.owner || "Unknown"]);
        out.push(["Permissions:", Model.permissionsText(live.mode)]);
        return out;
    }

    Shortcut { sequence: "Escape"; onActivated: root.close() }
    Shortcut { sequence: "Ctrl+W"; enabled: !root.win98; onActivated: root.close() }
    onClosing: if (!win98) rename()

    WindowScale {
        anchors.fill: parent
        devicePixelRatio: metrics.devicePixelRatio
        NativeWindowMetrics { id: metrics }
        Loader {
            id: frame
            width: parent.width
            sourceComponent: root.win98 ? memphis : platinum
        }
    }

    // Label and value rows; values wrap in the room the window gives them.
    component Facts: Column {
        id: facts
        spacing: root.win98 ? 6 * root.u : 6
        readonly property real labelWidth: root.win98 ? 64 * root.u : 92
        readonly property real gap: root.win98 ? 8 * root.u : 10
        Repeater {
            model: root.rows
            Item {
                required property var modelData
                width: facts.width
                height: Math.max(label.height, value.height)
                FilesText {
                    id: label
                    width: facts.labelWidth
                    horizontalAlignment: root.win98 ? Text.AlignLeft : Text.AlignRight
                    text: parent.modelData[0]
                    small: !root.win98
                }
                FilesText {
                    id: value
                    x: facts.labelWidth + facts.gap
                    width: facts.width - x
                    text: parent.modelData[1]
                    wrap: true
                    small: !root.win98
                }
            }
        }
    }
    component NameRow: Item {
        id: nameRow
        implicitHeight: Math.max(icon.height, root.renamable ? field.height : plainName.height)
        function focusName() { field.takeFocus(); field.selectBase(); }
        EntryIcon {
            id: icon
            art: Model.artName(root.live)
            large: true
            alias: root.live.kind === "alias"
        }
        FilesField {
            id: field
            objectName: "infoName"
            x: icon.width + (root.win98 ? 10 * root.u : 10)
            anchors.verticalCenter: icon.verticalCenter
            width: nameRow.width - x
            height: root.win98 ? Win98Tokens.fieldHeight * root.u : 24
            visible: root.renamable
            accessibleName: "Name"
            text: root.shownName
            onEdited: function(value) { root.draft = value; }
            onAccepted: { if (root.rename() && !root.win98) root.close(); }
            onEscaped: root.close()
        }
        FilesText {
            id: plainName
            visible: !root.renamable
            x: field.x
            anchors.verticalCenter: icon.verticalCenter
            width: nameRow.width - x
            text: root.shownName
            wrap: true
            italic: root.live.kind === "alias" && !root.win98
        }
    }

    Component {
        id: platinum
        Item {
            implicitHeight: column.implicitHeight + infoTitle.height + 32
            function focusName() { nameRow.focusName(); }
            PlatinumBevel { anchors.fill: parent; color: PlatinumTokens.menuSurface }
            PlatinumTitleBar {
                id: infoTitle
                x: PlatinumTokens.hairFor(metrics.devicePixelRatio)
                y: x
                width: parent.width - 2 * x
                window: root
                zoomable: false
                collapsible: false
                onCloseClicked: root.close()
            }
            Column {
                id: column
                x: 16
                y: infoTitle.y + infoTitle.height + 14
                width: parent.width - 32
                spacing: 12
                NameRow { id: nameRow; width: column.width }
                Rectangle { width: column.width; height: PlatinumTokens.hairFor(metrics.devicePixelRatio); color: PlatinumTokens.bevelDark }
                Facts { width: column.width }
                FilesCheckBox {
                    objectName: "lockedBox"
                    text: "Locked"
                    checked: Model.isLocked(root.live.mode)
                    enabled: false
                    Accessible.description: "Shows whether the write permission is off."
                }
                FilesText {
                    visible: root.problem !== ""
                    width: column.width
                    wrap: true
                    small: true
                    color: PlatinumTokens.menuDanger
                    text: root.problem
                }
            }
            WindowEdges { anchors.fill: parent; window: root }
        }
    }
    Component {
        id: memphis
        Item {
            implicitHeight: box.implicitHeight
            function focusName() { nameRow.focusName(); }
            Win98Window {
                id: box
                width: root.width
                title: root.title
                showHelp: false
                onCloseClicked: root.close()
                Column {
                    id: memphisColumn
                    width: root.width - 22 * root.u
                    spacing: 8 * root.u
                    // The General tab.
                    Item {
                        width: memphisColumn.width
                        height: 18 * root.u
                        Win98Bevel { width: tabText.width + 12 * root.u; height: 20 * root.u; variant: "window" }
                        Win98Text { id: tabText; x: 6 * root.u; y: 4 * root.u; text: "General"; accessMarks: false }
                    }
                    NameRow { id: nameRow; width: memphisColumn.width }
                    Win98Separator { width: memphisColumn.width }
                    Facts { width: memphisColumn.width }
                    Win98Separator { width: memphisColumn.width }
                    Row {
                        spacing: 12 * root.u
                        Win98Text { text: "Attributes:"; accessMarks: false }
                        FilesCheckBox {
                            objectName: "readOnlyBox"
                            text: "Read-only"
                            checked: Model.isLocked(root.live.mode)
                            enabled: false
                        }
                        FilesCheckBox {
                            text: "Hidden"
                            checked: root.live.hidden === true
                            enabled: false
                        }
                    }
                    Win98Text {
                        visible: root.problem !== ""
                        width: memphisColumn.width
                        wrap: true
                        text: root.problem
                        accessMarks: false
                        color: Win98Tokens.danger
                    }
                    Row {
                        x: memphisColumn.width - width
                        spacing: 6 * root.u
                        FilesButton { text: "OK"; isDefault: true; roleLabels: ["OK", "Cancel", "Apply"]; onClicked: { if (root.rename()) root.close(); } }
                        FilesButton { text: "Cancel"; roleLabels: ["OK", "Cancel", "Apply"]; onClicked: root.close() }
                        FilesButton { text: "Apply"; roleLabels: ["OK", "Cancel", "Apply"]; enabled: root.renamable && root.draft.trim() !== root.live.name; onClicked: root.rename() }
                    }
                }
            }
            MouseArea {
                x: 3 * root.u; y: 3 * root.u
                width: parent.width - 30 * root.u
                height: Win98Tokens.captionHeight * root.u
                onPressed: root.startSystemMove()
            }
        }
    }
}
