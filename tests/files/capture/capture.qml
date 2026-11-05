import QtQuick
import QtTest
import Hensou
import Hensou.Files
import "../../../apps/files/qml/Model.js" as Model

// Captures for review: every key state in both themes and both modes, plus
// the folder window across the size ladder. tests/files/run.py grabs the
// output with grim at each HENSOU_CAPTURE line and writes an ack file.
TestCase {
    id: test
    name: "FilesCapture"
    when: windowShown
    width: 32
    height: 32
    property var app: null
    readonly property string ackDir: "/tmp/hensou-files-capture/ack"
    Component { id: appComponent; FilesApp { autoStart: false } }

    function acked(name) {
        const request = new XMLHttpRequest();
        request.open("GET", "file://" + ackDir + "/" + name, false);
        try { request.send(); } catch (e) { return false; }
        return request.responseText.indexOf("ok") === 0;
    }
    function capture(name) {
        wait(450);
        console.log("HENSOU_CAPTURE " + name);
        tryVerify(function() { return test.acked(name); }, 15000, "capture " + name);
    }
    function closeAll() {
        for (const a of app.alerts.slice()) a.close();
        for (const k in app.infoWindows) app.infoWindows[k].close();
        if (app.transfersWindow) app.transfersWindow.close();
        for (const w of app.windows.slice()) w.close();
        wait(150);
    }
    function open(location, w, h) {
        const win = app.openLocation(location, {});
        verify(win);
        if (w) { win.width = w; win.height = h; }
        tryVerify(function() { return win.visible && win.listing && (win.listing.status === "ready" || win.listing.status === "error"); }, 4000);
        return win;
    }
    function entryNamed(w, name) {
        for (const e of w.allEntries) if (e.name === name) return e;
        return null;
    }
    function waitAlert(kind) {
        tryVerify(function() { return app.alerts.some(function(a) { return a.spec.kind === kind && a.visible; }); }, 4000, kind);
    }

    function test_capture_states() {
        for (const theme of ["platinum", "win98"]) {
            for (const mode of ["light", "dark"]) {
                Theme.name = theme;
                Theme.mode = mode;
                Theme.extraState = "off";
                if (app) { app.destroy(); wait(50); }
                app = appComponent.createObject(test);
                const tag = (theme === "win98" ? "memphis" : "platinum") + "-" + mode;

                open(Model.computer(), 560, 380);
                capture(tag + "-computer");
                closeAll();

                let w = open(Model.local("/home/fixture"), 760, 520);
                tryVerify(function() { return w.memoryLoaded; });
                w.setMemory({ show_hidden: true, view: "icons" });
                w.select(entryNamed(w, "Stress alias"), 0);
                capture(tag + "-listing-hidden-aliases");
                w.setMemory({ view: "list" });
                capture(tag + "-listing-list");
                w.setMemory({ show_hidden: false, view: "icons" });
                closeAll();

                w = open(Model.local("/home/fixture/Stress"), 700, 480);
                w.setMemory({ view: "list" });
                capture(tag + "-many-items");
                w.setMemory({ view: "icons" });
                closeAll();

                w = app.openLocation(Model.host("fuji", "/"), {});
                waitAlert("host-key");
                capture(tag + "-host-key");
                closeAll();

                w = app.openLocation(Model.host("nara", "/"), {});
                waitAlert("changed-key");
                capture(tag + "-changed-key");
                closeAll();

                open(Model.host("kaiju", "/"), 620, 400);
                capture(tag + "-reconnecting");
                closeAll();

                const t = app.showTransfers();
                tryVerify(function() { return t.visible; });
                capture(tag + "-transfers-conflict");
                t.width = 420; t.height = 640;
                capture(tag + "-transfers-narrow");
                closeAll();
                app.transfersWindow.destroy();
                app.transfersWindow = null;

                w = open(Model.local("/home/fixture"), 520, 360);
                const info = app.openInfo(entryNamed(w, "Read-only notes.txt"));
                tryVerify(function() { return info.visible; });
                capture(tag + "-get-info");
                info.close();
                const iso = app.openInfo(entryNamed(w, "disk-image.iso"));
                tryVerify(function() { return iso.visible; });
                capture(tag + "-get-info-unknown-size");
                iso.close();

                // Trash: Memphis asks before the Recycle Bin; both warn
                // before a permanent delete; Empty Trash defaults to Cancel.
                if (theme === "win98") {
                    w.select(entryNamed(w, "photo.jpg"), 0);
                    w.act("trash");
                    waitAlert("move-to-trash");
                    capture(tag + "-trash-confirm");
                    for (const a of app.alerts.slice()) a.close();
                }
                app.trashEntries([{ location: Model.local("/run/media/fixture/USB/movie.mkv"), name: "movie.mkv", kind: "file" }], w, false);
                waitAlert("delete-permanently");
                capture(tag + "-delete-permanently");
                for (const a of app.alerts.slice()) a.close();
                app.emptyTrash(w);
                waitAlert("empty-trash");
                capture(tag + "-empty-trash");
                closeAll();

                w = open(Model.computer(), 560, 380);
                w.select(w.entries.filter(function(e) { return e.kind === "volume"; })[0], 0);
                w.act("eject");
                waitAlert("eject-busy");
                capture(tag + "-eject-busy");
                closeAll();

                // The size ladder: tiny, narrow-tall, wide-short, medium, generous.
                if (mode === "light") {
                    for (const size of [[190, 130], [260, 620], [1100, 190], [700, 480], [1300, 850]]) {
                        w = open(Model.local("/home/fixture"), size[0], size[1]);
                        w.setMemory({ view: size[0] > 1000 ? "list" : "icons" });
                        capture(tag + "-ladder-" + size[0] + "x" + size[1]);
                        closeAll();
                    }
                    const tw = app.showTransfers();
                    tw.width = 240; tw.height = 200;
                    capture(tag + "-ladder-transfers-240x200");
                    closeAll();
                }
            }
        }
    }
}
