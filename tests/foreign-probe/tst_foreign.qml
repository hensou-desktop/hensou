import QtQuick
import QtTest

Item {
    id: root
    property int received: 0
    Window {
        id: foreignWindow
        onActiveChanged: {
            if (active) sink.forceActiveFocus();
            console.log("FOREIGN_ACTIVE", active, sink.activeFocus, activeFocusItem);
        }
        title: "Hensou foreign probe"
        width: 200
        height: 160
        visible: true
        Item {
            id: sink
            onActiveFocusChanged: console.log("FOREIGN_ITEM_FOCUS", activeFocus)
            anchors.fill: parent
            focus: true
            Keys.onPressed: function(event) {
                console.log("FOREIGN_KEY", event.key, event.modifiers);
                if (event.key === Qt.Key_F13) {
                    root.received++;
                    console.log("FOREIGN_F13", root.received);
                    event.accepted = true;
                }
            }
        }
    }
    TestCase {
        name: "ForeignProbe"
        when: windowShown
        function test_listen() {
            sink.forceActiveFocus();
            console.log("FOREIGN_INITIAL", foreignWindow.active, sink.activeFocus, foreignWindow.activeFocusItem);
            wait(90000);
        }
    }
}
