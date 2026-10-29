import QtQuick
import QtTest

Item {
    id: root
    property int received: 0
    Window {
        title: "Hensou foreign probe"
        width: 200
        height: 160
        visible: true
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: function(event) {
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
        function test_listen() { wait(90000); }
    }
}
