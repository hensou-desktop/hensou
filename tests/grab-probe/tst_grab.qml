import QtQuick
import QtTest
import Hensou.Demo

TestCase {
    name: "NativeGrab"
    when: windowShown
    Component { id: appComponent; DemoWindow {} }
    function test_cross_client() {
        const app = createTemporaryObject(appComponent, null);
        verify(app);
        console.log("HENSOU_PHASE prime-input");
        wait(150);
        console.log("HENSOU_PHASE probe-foreign-positive");
        wait(350);
        console.log("HENSOU_PHASE probe-focus-owner");
        wait(150);
        tryCompare(app, "active", true);
        const button = findChild(app, "moreButton");
        button.takeFocus();
        tryCompare(button.item, "activeFocus", true);
        console.log("HENSOU_PHASE open-native-menu");
        const menu = findChild(app, "actionsMenu");
        tryCompare(menu, "opened", true);
        let received = 0;
        menu.contentItem.Keys.pressed.connect(function(event) {
            if (event.key === Qt.Key_F13) {
                received++;
                console.log("POPUP_F13", received);
                event.accepted = true;
            }
        });
        verify(waitForRendering(menu.contentItem));
        console.log("HENSOU_PHASE probe-foreign-pointer");
        wait(250);
        verify(menu.opened, "Native popup closed during the foreign pointer motion");
        console.log("HENSOU_PHASE probe-foreign-key");
        tryVerify(function() { return received === 1; });
        console.log("HENSOU_PHASE close-native-menu");
        tryCompare(menu, "opened", false);
        console.log("HENSOU_PHASE probe-after-close");
        wait(200);
        compare(received, 1);
        app.close();
    }
}
