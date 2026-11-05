import QtQuick

// One row of a Memphis list view.
//
// One line (16 u): mark or icon, title, value at the right edge. Two lines
// (34 u): a detail line in grey under the title, or a level bar (the
// Sound window). Selected: the selection colour, white text (the detail
// too); with keyboard focus, a dotted rectangle on the row's edge.
//
// Alignment: every title starts on one edge (markUnits + 4 u in) and every
// value ends on one edge; a value column takes the width of the role's
// widest value (valueUnits), so 9%, 42% and 100% share an edge.
Item {
    id: root
    Accessible.role: Accessible.ListItem
    Accessible.name: title
    Accessible.description: detail
    Accessible.selected: selected
    Accessible.selectable: true
    Accessible.onPressAction: if (enabled) {
        const view = root.ListView.view;
        if (view) view.currentIndex = root.rowIndex();
        root.clicked();
        if (root.list) root.list.activated(root.rowIndex());
    }

    property string title: ""
    property string detail: ""
    property string value: ""
    property string iconName: ""       // a 16-u icon
    property string mark: ""           // "dot" or "ring", in a 10-u column
    property bool bold: false
    property real level: -1            // 0..1 shows a level bar as line two
    property bool muted: false
    property color detailColor: MemphisTokens.gray
    property color titleColor: MemphisTokens.winText
    property real valueUnits: 34
    // An icon in a 10-u column at the right edge (the Wi-Fi lock, the
    // brightness dot), "" for none.
    property string trailing: ""
    property bool selected: ListView.view ? ListView.isCurrentItem : false
    // The MemphisListView around the view, when the row is its delegate.
    readonly property MemphisListView list: ListView.view ? ListView.view.parent as MemphisListView : null
    property bool focused: selected && list !== null && list.focusShown

    signal clicked
    signal doubleClicked

    readonly property real u: 2 / WindowMetrics.ratio(root)
    readonly property bool twoLine: detail !== "" || level >= 0
    readonly property real markWidth: iconName !== "" ? 16 * u : mark !== "" ? 10 * u : 0
    readonly property color ink: selected ? MemphisTokens.selectionText : titleColor

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitWidth: 200 * u
    implicitHeight: (twoLine ? MemphisTokens.listRowTwo : MemphisTokens.listRow) * u

    Rectangle {
        anchors.fill: parent
        color: root.selected ? MemphisTokens.selection : "transparent"
    }

    Item {
        id: markCell
        visible: root.markWidth > 0
        x: 3 * root.u
        width: root.markWidth
        height: root.height
        MemphisIcon {
            name: root.iconName !== "" ? root.iconName : root.mark
            color: root.ink
            x: MemphisTokens.snap((markCell.width - width) / 2, root.u)
            y: MemphisTokens.snap((markCell.height - height) / 2, root.u)
        }
    }

    Column {
        id: textColumn
        x: 3 * root.u + (root.markWidth > 0 ? root.markWidth + 4 * root.u : 0)
        width: (root.value !== "" ? valueText.x - 4 * root.u
            : root.trailing !== "" ? root.width - 17 * root.u : root.width - 3 * root.u) - x
        y: MemphisTokens.snap((root.height - height) / 2, root.u)
        spacing: root.level >= 0 ? 3 * root.u : 0

        MemphisText {
            width: Math.min(implicitWidth, textColumn.width)
            text: root.title
            accessMarks: false
            bold: root.bold
            color: root.ink
        }
        MemphisText {
            visible: root.detail !== "" && root.level < 0
            width: Math.min(implicitWidth, textColumn.width)
            text: root.detail
            accessMarks: false
            color: root.selected ? MemphisTokens.selectionText : root.detailColor
        }
        MemphisLevelBar {
            visible: root.level >= 0
            width: textColumn.width
            value: root.level
            muted: root.muted
            onSelection: root.selected
        }
    }

    MemphisText {
        id: valueText
        visible: root.value !== ""
        x: root.width - 3 * root.u - width
        y: MemphisTokens.snap((root.height - height) / 2, root.u)
        width: Math.max(implicitWidth, root.valueUnits * root.u)
        horizontalAlignment: Text.AlignRight
        text: root.value
        accessMarks: false
        color: root.ink
    }

    Item {
        id: trailCell
        visible: root.trailing !== ""
        x: root.width - 13 * root.u
        width: 10 * root.u
        height: root.height
        MemphisIcon {
            name: root.trailing
            color: root.ink
            x: MemphisTokens.snap((trailCell.width - width) / 2, root.u)
            y: MemphisTokens.snap((trailCell.height - height) / 2, root.u)
        }
    }

    MemphisFocusRect {
        visible: root.focused
        anchors.fill: parent
        color: MemphisTokens.selectionText
    }

    // The row's index, from the view (the delegate may not declare one).
    function rowIndex() { return root.ListView.view ? root.ListView.view.indexAt(root.x + 1, root.y + 1) : -1; }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            const view = root.ListView.view;
            if (view) view.currentIndex = root.rowIndex();
            if (root.list) root.list.forceActiveFocus();
            root.clicked();
        }
        onDoubleClicked: {
            root.doubleClicked();
            if (root.list) root.list.activated(root.rowIndex());
        }
    }
}
