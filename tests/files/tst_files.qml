import QtQuick
import QtTest
import Hensou
import Hensou.Files
import "../../apps/files/qml/Model.js" as Model

// Files' key states in both themes, against the fixture service through the
// production seam (FilesBridge). Real native windows on headless Wayland.
TestCase {
    id: test
    name: "Files"
    when: windowShown
    width: 32
    height: 32
    property var app: null
    // QtQuickTest runs functions in alphabetical order; names below keep
    // the fixture-changing tests after the ones that read the same state.
    readonly property var themes: [{ tag: "platinum", theme: "platinum" }, { tag: "memphis", theme: "win98" }]
    Component { id: appComponent; FilesApp { autoStart: false } }

    function init() {
        Theme.name = "platinum";
        Theme.mode = "light";
        Theme.extraState = "off";
        app = createTemporaryObject(appComponent, test);
        verify(app);
        wait(30);
    }
    function cleanup() {
        if (!app) return;
        for (const a of app.alerts.slice()) a.close();
        for (const k in app.infoWindows) app.infoWindows[k].close();
        if (app.transfersWindow) { app.transfersWindow.close(); app.transfersWindow.destroy(); }
        for (const w of app.windows.slice()) w.close();
        wait(60);
    }
    function useTheme(theme) { Theme.name = theme; wait(30); }
    function open(location) {
        const w = app.openLocation(location, {});
        verify(w, "window for " + Model.key(location));
        tryVerify(function() { return w.visible && w.listing && w.listing.status !== "loading"; }, 4000, "listing for " + Model.key(location));
        return w;
    }
    function alertOf(kind) {
        for (const a of app.alerts) if (a.spec.kind === kind) return a;
        return null;
    }
    function waitAlert(kind) {
        tryVerify(function() { return alertOf(kind) !== null && alertOf(kind).visible; }, 4000, "alert " + kind);
        return alertOf(kind);
    }
    function entryNamed(w, name) {
        for (const e of w.allEntries) if (e.name === name) return e;
        return null;
    }

    // ---- the Computer window ----
    function test_computer_window_data() { return themes; }
    function test_computer_window(data) {
        useTheme(data.theme);
        const w = open(Model.computer());
        compare(w.title, data.theme === "win98" ? "My Computer" : "Myoko");
        const names = w.entries.map(function(e) { return Model.entryName(e, data.theme); });
        compare(names, data.theme === "win98" ? ["Home", "USB", "Network Neighborhood", "Recycle Bin"] : ["Home", "USB", "SSH Hosts", "Trash"]);
        verify(findChild(w, "menuRow"));
        // A second open of the same place brings that window forward.
        compare(app.openLocation(Model.computer(), {}), w);
        compare(app.windows.length, 1);
    }

    // ---- hidden files, remembered per folder; aliases ----
    function test_hidden_files_are_remembered_per_folder_data() { return themes; }
    function test_hidden_files_are_remembered_per_folder(data) {
        useTheme(data.theme);
        const home = Model.local("/home/fixture");
        let w = open(home);
        tryVerify(function() { return w.memoryLoaded; });
        const shown = w.entries.length;
        verify(w.hiddenCount >= 2);
        verify(!w.entries.some(function(e) { return e.hidden; }));
        verify(w.entries.some(function(e) { return e.kind === "alias"; }), "the fixture alias shows");
        w.act("hidden");
        compare(w.entries.length, shown + w.hiddenCount);
        w.saveMemory();
        w.close();
        wait(80);
        w = open(home);
        tryVerify(function() { return w.memoryLoaded; });
        compare(w.memory.show_hidden, true, "remembered for this folder");
        const other = open(Model.local("/home/fixture/Documents"));
        tryVerify(function() { return other.memoryLoaded; });
        compare(other.memory.show_hidden, false, "not for other folders");
        // Restore for the next theme's run.
        w.act("hidden");
        w.saveMemory();
    }

    // ---- unknown sizes are unknown ----
    function test_unknown_sizes_never_read_zero() {
        for (const theme of ["platinum", "win98"]) {
            const iso = { kind: "file", size: null, name: "disk-image.iso", icon: { name: "x" } };
            verify(Model.sizeText(null, theme, iso) !== "0" && Model.sizeText(null, theme, iso).indexOf("0") !== 0);
            compare(Model.sizeInfo(null, theme), "Unknown");
        }
    }

    // ---- host-key trust: Cancel is the default ----
    function test_host_key_trust_data() { return themes; }
    function test_host_key_trust(data) {
        useTheme(data.theme);
        const w = app.openLocation(Model.host("fuji", "/"), {});
        const a = waitAlert("host-key");
        verify(a.spec.fingerprint.indexOf("SHA256:") >= 0);
        compare(a.spec.defaultAction, "reject");
        const cancel = findChild(a.contentItem, "alertButton-reject");
        verify(cancel);
        compare(cancel.isDefault, true);
        compare(findChild(a.contentItem, "alertButton-trust").isDefault, false);
        verify(findChild(a.contentItem, "alertFingerprint").text.indexOf("SHA256:") >= 0);
        if (data.theme === "platinum") {
            // Return answers with the default: Cancel. Nothing is trusted.
            a.requestActivate();
            tryVerify(function() { return a.active; }, 2000);
            keyClick(Qt.Key_Return);
            tryVerify(function() { return alertOf("host-key") === null; });
            tryVerify(function() { return w.listing && w.listing.status === "error"; });
            compare(w.listing.error.kind, "host-key-rejected");
        } else {
            a.choose("trust");
            tryVerify(function() { return w.listing && w.listing.status === "ready"; }, 4000);
            verify(w.entries.length > 0);
        }
    }

    // ---- a changed key is refused ----
    function test_changed_key_is_refused_data() { return themes; }
    function test_changed_key_is_refused(data) {
        useTheme(data.theme);
        const w = app.openLocation(Model.host("nara", "/"), {});
        const a = waitAlert("changed-key");
        compare(a.spec.buttons.length, 1);
        verify(a.spec.fingerprint.indexOf("SHA256:") >= 0);
        a.choose("ok");
        tryCompare(w.banner, "kind", "refused");
        verify(!w.listing || w.listing.status !== "ready");
    }

    // ---- Reconnecting… keeps the last listing, greyed ----
    function test_reconnecting_host_is_greyed_data() { return themes; }
    function test_reconnecting_host_is_greyed(data) {
        useTheme(data.theme);
        const w = open(Model.host("kaiju", "/"));
        compare(w.banner.kind, "reconnecting");
        compare(w.banner.text, "Reconnecting\u2026");
        verify(w.greyed);
        verify(w.entries.length >= 4, "the last listing stays");
        const banner = findChild(w, "hostBanner");
        verify(banner);
        tryVerify(function() { return banner.visible; });
    }

    // ---- transfers: progress, conflict, waiting, working copies ----
    function test_transfers_window_shows_every_state_data() { return themes; }
    function test_transfers_window_shows_every_state(data) {
        useTheme(data.theme);
        const t = app.showTransfers();
        tryVerify(function() { return t.visible; });
        const conflict = findChild(t, "transfer-" + (Math.pow(2, 47) + 1));
        verify(conflict, "the conflict row");
        verify(findChild(conflict, "conflict-replace"));
        verify(findChild(conflict, "conflict-keep-both"));
        verify(findChild(conflict, "applyToAll").visible);
        compare(findChild(conflict, "conflict-stop").isDefault, true);
        const ask = findChild(t, "transfer-" + (Math.pow(2, 47) + 2));
        verify(findChild(ask, "keep-waiting").visible);
        verify(findChild(ask, "stop-waiting").visible);
        verify(findChild(t, "transfer-1"), "the waiting transfer");
        verify(findChild(t, "remote-overwrite"));
        verify(findChild(t, "remote-keep"));
        verify(findChild(t, "remote-copy"));
        verify(findChild(t, "stop-watching"));
        compare(app.tray.active, true);
        compare(app.tray.needsAttention, true);
    }

    function test_transfers_z_choices_reach_the_service() {
        useTheme("win98");
        const t = app.showTransfers();
        tryVerify(function() { return t.visible; });
        const id = Math.pow(2, 47) + 1;
        t.applyAll = { [String(id)]: true };
        t.choose(app.store.transfers[String(id)], "keep-both");
        tryCompare(app.store.transfers[String(id)].state, "state", "running");
        app.store.send({ command: "keep-waiting", id: id + 1, keep: true });
        tryCompare(app.store.transfers[String(id + 1)].state, "state", "waiting-for-host");
        const before = Object.keys(app.store.copies).length;
        const first = app.store.copies[Object.keys(app.store.copies)[0]];
        app.store.send({ command: "stop-watching", remote: first.remote });
        tryCompare(Object.keys(app.store.copies), "length", before - 1);
        // A new copy uses its request id as the transfer id.
        const req = app.store.transfer([Model.local("/home/fixture/notes.txt")], Model.local("/run/media/fixture/USB"), "copy");
        tryVerify(function() { return app.store.transfers[String(req)] !== undefined; });
        app.store.cancelTransfer(req);
        tryCompare(app.store.transfers[String(req)].state, "state", "cancelled");
    }

    // ---- Get Info / Properties ----
    function test_get_info_data() { return themes; }
    function test_get_info(data) {
        useTheme(data.theme);
        const w = open(Model.local("/home/fixture"));
        const locked = entryNamed(w, "Read-only notes.txt");
        verify(locked);
        const info = app.openInfo(locked);
        tryVerify(function() { return info.visible; });
        compare(info.title, data.theme === "win98" ? "Read-only notes.txt Properties" : "Read-only notes.txt Info");
        verify(info.renamable);
        const box = findChild(info.contentItem, data.theme === "win98" ? "readOnlyBox" : "lockedBox");
        verify(box);
        compare(box.checked, true);
        compare(box.enabled, false, "only the name can change");
        verify(info.rows.some(function(r) { return r[0] === "Permissions:" && r[1].indexOf("r--r--r--") === 0; }));
        info.close();
        const iso = app.openInfo(entryNamed(w, "disk-image.iso"));
        tryVerify(function() { return iso.visible; });
        verify(iso.rows.some(function(r) { return r[0] === "Size:" && r[1] === "Unknown"; }));
        iso.close();
        // Renaming through the name field.
        const notes = app.openInfo(entryNamed(w, data.theme === "win98" ? "run-backup.sh" : "empty.txt"));
        tryVerify(function() { return notes.visible; });
        notes.draft = "renamed " + data.tag + ".txt";
        verify(notes.rename());
        tryVerify(function() { return entryNamed(w, "renamed " + data.tag + ".txt") !== null; });
        notes.close();
    }

    // ---- Trash: Memphis asks, Platinum does not; both warn before
    // a permanent delete; Empty Trash defaults to Cancel. ----
    function test_move_to_trash_follows_each_os_data() { return themes; }
    function test_move_to_trash_follows_each_os(data) {
        useTheme(data.theme);
        const w = open(Model.local("/home/fixture"));
        const name = data.theme === "win98" ? "photo.jpg" : "notes.txt";
        w.select(entryNamed(w, name), 0);
        w.act("trash");
        if (data.theme === "win98") {
            const a = waitAlert("move-to-trash");
            compare(a.spec.defaultAction, "trash");
            a.choose("trash");
        } else {
            wait(200);
            compare(alertOf("move-to-trash"), null, "Platinum does not ask");
        }
        tryVerify(function() { return entryNamed(w, name) === null; }, 3000);
        verify(app.store.state.trash.some(function(t) { return t.entry.name === name; }));
    }
    function test_permanent_delete_and_empty_trash_warn_data() { return themes; }
    function test_permanent_delete_and_empty_trash_warn(data) {
        useTheme(data.theme);
        const w = open(Model.computer());
        app.trashEntries([{ location: Model.local("/run/media/fixture/USB/movie.mkv"), name: "movie.mkv", kind: "file" }], w, false);
        const a = waitAlert("delete-permanently");
        compare(a.spec.defaultAction, "cancel");
        compare(findChild(a.contentItem, "alertButton-cancel").isDefault, true);
        a.close();
        tryVerify(function() { return alertOf("delete-permanently") === null; });
        app.emptyTrash(w);
        const e = waitAlert("empty-trash");
        compare(e.spec.defaultAction, "cancel");
        compare(findChild(e.contentItem, "alertButton-cancel").isDefault, true);
        e.requestActivate();
        tryVerify(function() { return e.active; }, 2000);
        keyClick(Qt.Key_Escape);
        tryVerify(function() { return alertOf("empty-trash") === null; });
        verify(app.store.state.trash.length > 0, "Escape empties nothing");
    }

    // ---- Eject busy ----
    function test_eject_busy_alert_data() { return themes; }
    function test_eject_busy_alert(data) {
        useTheme(data.theme);
        const w = open(Model.computer());
        const usb = w.entries.filter(function(e) { return e.kind === "volume"; })[0];
        w.select(usb, 0);
        verify(w.volumeSelected);
        w.act("eject");
        const a = waitAlert("eject-busy");
        verify(a.spec.detail.indexOf("ghostty") >= 0);
    }

    // ---- Platinum spatial rules; Memphis navigation ----
    function test_platinum_spatial_windows() {
        useTheme("platinum");
        const home = open(Model.local("/home/fixture"));
        const docs = entryNamed(home, "Documents");
        home.activate(docs, 0);
        tryCompare(app.windows, "length", 2);
        // Option-double-click opens the child and closes the parent.
        const docWindow = app.windowFor(Model.local("/home/fixture/Documents"));
        verify(docWindow);
        app.openEnclosing(docWindow, true);
        tryVerify(function() { return !docWindow.visible; });
        verify(app.windowFor(Model.local("/home/fixture")));
        const again = app.windowFor(Model.local("/home/fixture"));
        again.activate(entryNamed(again, "Documents"), Model.ALT);
        tryVerify(function() { return !again.visible; });
        verify(app.windowFor(Model.local("/home/fixture/Documents")));
    }
    function test_memphis_explorer_navigates_in_place() {
        useTheme("win98");
        const w = open(Model.computer());
        const home = w.entries.filter(function(e) { return e.name === "Home"; })[0];
        w.activate(home, 0);
        tryCompare(w, "locationKey", Model.key(Model.local("/home/fixture")));
        compare(app.windows.length, 1);
        w.act("back");
        tryCompare(w, "locationKey", Model.key(Model.computer()));
        w.act("forward");
        tryCompare(w, "locationKey", Model.key(Model.local("/home/fixture")));
        const tree = findChild(w, "folderTree");
        verify(tree);
        tryVerify(function() { return tree.rows.some(function(r) { return r.name === "Network Neighborhood"; }); });
        verify(tree.rows.some(function(r) { return r.name === "Recycle Bin"; }));
    }

    // ---- a live theme switch keeps state ----
    function test_theme_switch_keeps_selection_and_view() {
        useTheme("platinum");
        const w = open(Model.local("/home/fixture"));
        w.select(entryNamed(w, "Documents"), 0);
        w.act("view-list");
        for (const theme of ["win98", "platinum", "win98"]) {
            Theme.name = theme;
            Theme.mode = theme === "win98" ? "dark" : "light";
            wait(60);
            compare(w.selectedEntries.length, 1);
            compare(w.selectedEntries[0].name, "Documents");
            compare(w.memory.view, "list");
            verify(findChild(w, "folderContent"));
        }
    }

    // ---- no capability becomes unreachable at any size ----
    function test_every_menu_stays_reachable_at_every_size_data() { return themes; }
    function test_every_menu_stays_reachable_at_every_size(data) {
        useTheme(data.theme);
        const w = open(Model.local("/home/fixture"));
        for (const size of [[180, 120], [240, 640], [320, 220], [1000, 160], [640, 440], [1400, 900]]) {
            w.width = size[0];
            w.height = size[1];
            wait(80);
            const row = findChild(w, "menuRow");
            verify(row, "menu row at " + size);
            const menus = w.menus();
            const inline = row.inlineCount;
            const overflowActions = row.overflowEntries.filter(function(e) { return e.action; }).map(function(e) { return e.action; });
            for (let i = inline; i < menus.length; i++)
                for (const e of menus[i].entries) if (e.action) verify(overflowActions.indexOf(e.action) >= 0, e.action + " reachable at " + size);
            if (inline < menus.length) verify(findChild(w, "menuTitle-overflow").visible, "overflow title at " + size);
            const content = findChild(w, "folderContent");
            verify(content.height > 0, "content has room at " + size);
            if (data.theme === "win98") {
                const toolbar = findChild(w, "toolbar");
                if (toolbar.visible && toolbar.inlineCount < toolbar.tools.length) verify(findChild(w, "toolOverflow").visible);
                // The tree's places stay in the Go menu when the tree yields.
                const go = menus.filter(function(m) { return m.id === "go"; })[0];
                verify(go.entries.some(function(e) { return e.text === "Network Neighborhood"; }));
            }
        }
    }

    // ---- clipboard offers files with text/uri-list ----
    function test_copy_offers_locations() {
        useTheme("win98");
        const w = open(Model.local("/home/fixture"));
        w.select(entryNamed(w, "Documents"), 0);
        w.act("cut");
        verify(app.cutKeys[Model.key(Model.local("/home/fixture/Documents"))]);
        const offered = FilesNative.clipboard();
        if (offered.locations) {
            const locations = JSON.parse(offered.locations);
            compare(locations[0].path, "/home/fixture/Documents");
            compare(offered.cut, true);
        } else {
            // A headless seat without keyboard focus may refuse the selection.
            skip("the compositor did not accept the clipboard selection");
        }
    }

    // ---- the tray item exists while transfers run ----
    function test_tray_follows_transfers() {
        compare(app.tray.active, Model.trayState(app.store.transfers).active);
        compare(app.tray.toolTip, Model.trayState(app.store.transfers).toolTip);
    }
}
