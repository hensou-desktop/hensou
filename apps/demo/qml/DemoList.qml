import QtQuick
import Hensou

Loader {
    id: root
    required property QtObject modelState
    signal activated(int index)
    signal focused()
    sourceComponent: Theme.name === "win98" ? win98 : platinum
    function takeFocus() { if (item) item.view.forceActiveFocus(); }
    Connections {
        target: root.item ? root.item.view : null
        function onActiveFocusChanged() { if (target.activeFocus) root.focused(); }
    }
    onLoaded: Qt.callLater(function() {
        if (!root.item) return;
        if (root.modelState.selectedIndex >= 0) root.item.view.positionViewAtIndex(root.modelState.selectedIndex, ListView.Contain);
        if (root.modelState.focusTarget === "list") root.takeFocus();
    })
    Component {
        id: platinum
        PlatinumMenuList {
            id: platinumList
            objectName: "fixtureList"
            model: root.modelState.rows
            currentIndex: root.modelState.selectedIndex
            activeFocusOnTab: true
            Accessible.role: Accessible.List
            Accessible.name: "Fixture rows"
            onCurrentIndexChanged: if (currentIndex >= 0) root.modelState.selectedIndex = currentIndex
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
                onClicked: { root.modelState.selectedIndex = index; platinumList.view.forceActiveFocus(); }
                onDoubleClicked: root.activated(index)
            }
            DemoLabel {
                anchors.centerIn: parent
                width: parent.width
                text: "No rows. Choose a fixture in More."
                wrap: true
                visible: root.modelState.rows.length === 0
            }
        }
    }
    Component {
        id: win98
        Win98ListView {
            id: win98List
            objectName: "fixtureList"
            model: root.modelState.rows
            currentIndex: root.modelState.selectedIndex
            emptyText: "No rows. Choose a fixture in More."
            rowUnits: Win98Tokens.listRow
            Accessible.role: Accessible.List
            Accessible.name: "Fixture rows"
            onCurrentIndexChanged: if (currentIndex >= 0) root.modelState.selectedIndex = currentIndex
            onActivated: function(index) { root.activated(index); }
            onActiveFocusChanged: if (activeFocus) root.focused()
            delegate: Win98ListRow {
                required property int index
                required property string modelData
                title: modelData
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData
                Accessible.selected: selected
                onClicked: { root.modelState.selectedIndex = index; win98List.view.forceActiveFocus(); }
                onDoubleClicked: root.activated(index)
            }
        }
    }
}
