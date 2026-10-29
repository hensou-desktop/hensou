import QtQuick
import Hensou

Loader {
    id: root
    required property QtObject state
    signal activated(int index)
    signal focused()
    implicitWidth: item ? item.implicitWidth : 0
    implicitHeight: item ? item.implicitHeight : 0
    sourceComponent: Theme.name === "win98" ? win98 : platinum
    function takeFocus() { if (item) item.forceActiveFocus(); }
    onLoaded: Qt.callLater(function() {
        if (!root.item) return;
        if (root.state.selectedIndex >= 0) root.item.view.positionViewAtIndex(root.state.selectedIndex, ListView.Contain);
        if (root.state.focusTarget === "list") root.takeFocus();
    })
    Component {
        id: platinum
        PlatinumMenuList {
            id: platinumList
            objectName: "fixtureList"
            model: root.state.rows
            currentIndex: root.state.selectedIndex
            activeFocusOnTab: true
            Accessible.role: Accessible.List
            Accessible.name: "Fixture rows"
            onCurrentIndexChanged: if (currentIndex >= 0) root.state.selectedIndex = currentIndex
            onActivated: function(index) { root.activated(index); }
            onActiveFocusChanged: if (activeFocus) root.focused()
            delegate: PlatinumMenuListRow {
                required property int index
                required property string modelData
                width: platinumList.view.width
                name: modelData
                selected: index === platinumList.currentIndex
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData
                Accessible.selected: selected
                onClicked: { root.state.selectedIndex = index; platinumList.forceActiveFocus(); }
                onDoubleClicked: root.activated(index)
            }
            DemoLabel {
                anchors.centerIn: parent
                width: parent.width
                text: "No rows. Choose a fixture in More."
                wrap: true
                visible: root.state.rows.length === 0
            }
        }
    }
    Component {
        id: win98
        Win98ListView {
            id: win98List
            objectName: "fixtureList"
            model: root.state.rows
            currentIndex: root.state.selectedIndex
            emptyText: "No rows. Choose a fixture in More."
            rowUnits: Win98Tokens.listRow
            Accessible.role: Accessible.List
            Accessible.name: "Fixture rows"
            onCurrentIndexChanged: if (currentIndex >= 0) root.state.selectedIndex = currentIndex
            onActivated: function(index) { root.activated(index); }
            onActiveFocusChanged: if (activeFocus) root.focused()
            delegate: Win98ListRow {
                required property int index
                required property string modelData
                title: modelData
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData
                Accessible.selected: selected
                onClicked: { root.state.selectedIndex = index; win98List.forceActiveFocus(); }
                onDoubleClicked: root.activated(index)
            }
        }
    }
}
