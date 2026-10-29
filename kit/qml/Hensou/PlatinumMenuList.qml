import QtQuick
import QtQuick.Layouts

// A menu's list: as tall as its rows, until the menu runs out of screen,
// then it scrolls with a Platinum scroll bar on the menu's right edge.
// scrolls tells the frame to move its right edge in by the bar.
Item {
    id: root
    Accessible.role: Accessible.List
    Accessible.name: ""


    property bool extendedNavigationEnabled: true
    activeFocusOnTab: enabled
    signal activated(int index)
    property alias view: list
    property alias model: list.model
    property alias delegate: list.delegate
    property alias currentIndex: list.currentIndex
    property alias count: list.count
    property alias spacing: list.spacing
    readonly property bool scrolls: scrollBar.needed

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: list.contentHeight
    implicitHeight: list.contentHeight

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        focus: true
        Keys.onPressed: event => {
            if (!root.extendedNavigationEnabled || !root.enabled || count === 0) return;
            const pitch = Math.max(1, (currentItem ? currentItem.height : PlatinumTokens.menuLine) + spacing);
            const page = Math.max(1, Math.floor(height / pitch) - 1);
            let next = currentIndex;
            if (event.key === Qt.Key_Home) next = 0;
            else if (event.key === Qt.Key_End) next = count - 1;
            else if (event.key === Qt.Key_PageDown) next = Math.min(count - 1, Math.max(0, currentIndex) + page);
            else if (event.key === Qt.Key_PageUp) next = Math.max(0, currentIndex - page);
            else return;
            currentIndex = next;
            positionViewAtIndex(next, ListView.Contain);
            event.accepted = true;
        }
        Keys.onReturnPressed: root.activated(currentIndex)
        Keys.onEnterPressed: root.activated(currentIndex)
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: true
        highlightMoveDuration: 0
        interactive: contentHeight > height
    }

    PlatinumScrollBar {
        id: scrollBar
        flickable: list
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    function moveSelection(offset) {
        if (list.count === 0) return;
        list.currentIndex = (list.currentIndex + offset + list.count) % list.count;
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
}
