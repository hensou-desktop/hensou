import QtQuick
import Hensou
import Hensou.Files
import "Model.js" as Model
import "Alerts.js" as Alerts

// The resident root: one per process. It owns the store, every window, the
// transfers window, alerts and the transfer indicator. Windows come and go;
// this object and the transfers it watches stay.
QtObject {
    id: app
    readonly property string theme: Theme.name === "memphis" ? "memphis" : "platinum"
    readonly property string hostname: FilesBridge.hostname
    property FilesStore store: FilesStore {}
    property var windows: []
    property var infoWindows: ({})
    property var transfersWindow: null
    property var alerts: []
    // Cut items (Memphis) draw dimmed until pasted.
    property var cutKeys: ({})
    // Set false in tests that drive requests themselves.
    property bool autoStart: true
    // Set by a Files drop target during a drag that started in Files.
    property bool internalDrop: false

    signal windowOpened(var window)

    property Component folderComponent: Component { FolderWindow {} }
    property Component alertComponent: Component { AlertWindow {} }
    property Component infoComponent: Component { InfoWindow {} }
    property Component transfersComponent: Component { TransfersWindow {} }

    property TransferTray tray: TransferTray {
        active: app.store.tray.active
        needsAttention: app.store.tray.attention
        title: "Files"
        toolTip: app.store.tray.toolTip
        onShowTransfersRequested: app.showTransfers()
        onCancelAllRequested: app.store.cancelAll()
    }

    // A started transfer still running after this long shows its progress.
    property Timer progressTimer: Timer {
        interval: 800
        onTriggered: {
            for (const id in app.store.started) {
                const t = app.store.transfers[id];
                if (t && Model.transferActive(t)) { app.showTransfers(); return; }
            }
        }
    }

    property Connections storeEvents: Connections {
        target: app.store
        function onHostKeyRequested(prompt) { app.askHostKey(prompt); }
        function onHostRefused(host, fingerprint) {
            app.alert(Alerts.changedKey(host, fingerprint, app.theme), app.frontWindow(), null);
        }
        function onTransferUpdated(transfer) {
            if (!app.store.started[String(transfer.id)]) return;
            if (Model.transferNeedsChoice(transfer)) app.showTransfers();
            else if (Model.transferActive(transfer)) app.progressTimer.restart();
        }
        function onFailed(request, error) {
            // Errors of listings show in their windows; others need a word.
            if (request !== null && request !== undefined && error.kind !== "host-key-rejected")
                app.alert(Alerts.failure(Model.errorText(error), app.theme), app.frontWindow(), null);
        }
    }

    property Connections handoff: Connections {
        target: FilesBridge
        function onOpenRequested(json) { app.handle(JSON.parse(json)); }
    }

    Component.onCompleted: {
        store.connect();
        if (!autoStart) return;
        const pending = JSON.parse(FilesBridge.takeRequests() || "[]");
        for (const request of pending) handle(request);
    }

    // ---- launch requests ----
    function handle(request) {
        if (request.request === "computer") return openLocation(Model.computer(), {});
        if (request.request === "open") return openLocation(request.location, {});
        return null; // daemon: no window
    }

    // ---- windows ----
    function windowFor(location) {
        for (const w of windows) if (w.visible && Model.same(w.location, location)) return w;
        return null;
    }
    function frontWindow() {
        for (const w of windows) if (w.active) return w;
        return windows.length ? windows[windows.length - 1] : null;
    }
    // Platinum: one spatial window per folder; an open folder comes to the
    // front. Memphis: a window navigates in place (options.from), unless a
    // new window is asked for.
    function openLocation(location, options) {
        const o = options || {};
        const existing = windowFor(location);
        if (existing) {
            existing.raiseWindow();
            if (o.closeFrom && o.from && o.from !== existing) o.from.close();
            return existing;
        }
        if (theme === "memphis" && o.from && !o.newWindow) {
            o.from.navigate(location);
            return o.from;
        }
        const w = folderComponent.createObject(null, { app: app, location: location });
        if (!w) {
            console.error("Files: cannot create a window:", folderComponent.errorString());
            return null;
        }
        windows = windows.concat([w]);
        w.closing.connect(function() { app.forget(w); });
        w.show();
        w.raiseWindow();
        if (o.closeFrom && o.from) o.from.close();
        windowOpened(w);
        return w;
    }
    function forget(w) {
        windows = windows.filter(function(x) { return x !== w; });
        w.destroy(1000);
    }
    function openEnclosing(from, closeFrom) {
        const up = Model.parent(from.location);
        if (up) openLocation(up, { from: from, closeFrom: closeFrom, newWindow: theme !== "memphis" });
    }

    // ---- entries ----
    // Opening follows aliases; folders open windows; files go to the
    // default desktop handler (remote files as working copies).
    function openEntry(entry, from, closeFrom) {
        if (Model.isContainer(entry)) return openLocation(Model.openTarget(entry), { from: from, closeFrom: closeFrom });
        store.send({ command: "open", location: Model.openTarget(entry) });
        return null;
    }
    function openInfo(entry) {
        const k = Model.key(entry.location);
        let w = infoWindows[k];
        if (!w) {
            w = infoComponent.createObject(null, { app: app, entry: entry });
            const next = Object.assign({}, infoWindows);
            next[k] = w;
            infoWindows = next;
            w.closing.connect(function() {
                const rest = Object.assign({}, app.infoWindows);
                delete rest[k];
                app.infoWindows = rest;
                w.destroy(1000);
            });
        }
        w.show();
        w.raise();
        w.requestActivate();
        store.send({ command: "info", location: entry.location });
        return w;
    }
    function showTransfers() {
        if (!transfersWindow) transfersWindow = transfersComponent.createObject(null, { app: app });
        transfersWindow.show();
        transfersWindow.raise();
        transfersWindow.requestActivate();
        return transfersWindow;
    }

    // ---- alerts ----
    function alert(spec, owner, done) {
        const a = alertComponent.createObject(null, { app: app, spec: spec, owner: owner || null });
        if (!a) {
            console.error("Files: cannot create an alert:", alertComponent.errorString());
            return null;
        }
        alerts = alerts.concat([a]);
        a.finished.connect(function(action) {
            app.alerts = app.alerts.filter(function(x) { return x !== a; });
            a.destroy(1000);
            if (done) done(action);
        });
        a.present();
        return a;
    }
    function askHostKey(prompt) {
        for (const a of alerts) if (a.spec.kind === "host-key" && a.spec.host === prompt.host) return;
        const spec = Alerts.hostKey(prompt, theme);
        spec.host = prompt.host;
        alert(spec, frontWindow(), function(action) {
            if (action === "trust") {
                store.send({ command: "trust-host-key", host: prompt.host, fingerprint: prompt.fingerprint });
            } else {
                store.send({ command: "reject-host-key", host: prompt.host });
                store.state = Model.rejectHost(store.state, prompt.host);
            }
        });
    }

    // ---- deleting ----
    // Platinum moves to the Trash at once; Memphis asks first. Both warn
    // before a permanent delete, which the service reports per location.
    function trashEntries(entries, owner, forcePermanent) {
        if (!entries.length) return;
        const locations = entries.map(function(e) { return e.location; });
        const names = entries.map(function(e) { return Model.entryName(e, theme); });
        if (forcePermanent) return confirmPermanent(locations, names, "", owner);
        store.send({ command: "check-delete", locations: locations }, function(event) {
            if (event.event !== "delete-check") return;
            const permanent = event.results.filter(function(r) { return r[1].type === "permanent"; });
            if (permanent.length) {
                return confirmPermanent(locations, names, permanent[0][1].reason, owner);
            }
            if (theme === "memphis") {
                alert(Alerts.moveToTrash(names, theme), owner, function(action) {
                    if (action === "trash") store.send({ command: "move-to-trash", locations: locations });
                });
            } else {
                store.send({ command: "move-to-trash", locations: locations });
            }
        });
    }
    function confirmPermanent(locations, names, reason, owner) {
        alert(Alerts.deletePermanently(names, reason, theme), owner, function(action) {
            if (action === "delete") store.send({ command: "delete-permanently", locations: locations });
        });
    }
    function emptyTrash(owner) {
        const items = store.state.trash;
        let bytes = 0;
        for (const t of items) {
            if (t.entry.size === null || t.entry.size === undefined) { bytes = null; break; }
            bytes += t.entry.size;
        }
        alert(Alerts.emptyTrash(items.length, bytes, theme), owner, function(action) {
            if (action === "empty") store.send({ command: "empty-trash" });
        });
    }
    function restore(entries) {
        const stored = entries.map(function(e) { return e.location; });
        store.send({ command: "restore-from-trash", items: stored });
    }

    // ---- volumes ----
    function volumeFor(entry) {
        const path = entry.location ? entry.location.path : "";
        for (const v of store.state.volumes)
            if (v.mount_point === path || v.label === entry.name) return v;
        return null;
    }
    function eject(entry, owner) {
        const v = volumeFor(entry);
        if (!v) return;
        store.send({ command: "eject", volume_id: v.id }, function(event) {
            if (event.event === "error" && event.error.kind === "volume-busy")
                alert(Alerts.ejectBusy(v.label, event.error.holders, theme), owner, null);
            else if (event.event === "error")
                alert(Alerts.failure(Model.errorText(event.error), theme), owner, null);
        });
    }

    // ---- clipboard (text/uri-list with other apps) ----
    // Remote files start downloading at Copy; the paths reach the clipboard
    // reader after the download (FilesNative waits for Prepared).
    function prepareOffer(locations) {
        const remote = locations.filter(Model.isRemote);
        if (!remote.length) return { urls: locations.map(function(l) { return Model.fileUrl(l.path); }), pending: 0 };
        const id = store.send({ command: "prepare", locations: locations });
        if (id) {
            const next = Object.assign({}, store.started);
            next[String(id)] = true;
            store.started = next;
        }
        return { urls: [], pending: id };
    }
    function copyEntries(entries, cut) {
        const locations = entries.map(function(e) { return e.location; });
        if (!locations.length) return;
        const offer = prepareOffer(locations);
        FilesNative.setClipboard(offer.urls, JSON.stringify(locations), cut, offer.pending);
        const keys = {};
        if (cut) for (const l of locations) keys[Model.key(l)] = true;
        cutKeys = keys;
    }
    function canPaste() {
        const c = FilesNative.clipboard();
        return !!(c.locations && c.locations.length > 2) || !!(c.urls && c.urls.length);
    }
    function paste(destination) {
        const c = FilesNative.clipboard();
        let sources = [];
        if (c.locations) {
            try { sources = JSON.parse(c.locations); } catch (e) { sources = []; }
        }
        if (!sources.length) sources = Model.urlsToLocations(c.urls || []);
        if (!sources.length || Model.isVirtual(destination)) return 0;
        const id = store.transfer(sources, destination, c.cut ? "move" : "copy");
        if (c.cut) {
            FilesNative.clearClipboard();
            cutKeys = {};
        }
        return id;
    }
}
