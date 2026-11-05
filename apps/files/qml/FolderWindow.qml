import QtQuick
import QtQuick.Controls
import Hensou
import Hensou.Host
import Hensou.Files
import "Model.js" as Model
import "LayoutPlan.js" as LayoutPlan

// One Files window. Platinum: one spatial window per folder. Memphis: an
// Explorer window that navigates in place, with a folder tree. The window
// owns its state (location, selection, view memory, history, tree) outside
// the theme Loader, so a live theme switch keeps all of it.
ApplicationWindow {
    id: win
    required property var app
    property var location: Model.computer()

    // ---- state that survives theme switches and layout changes ----
    property var memory: ({ geometry: null, view: "icons", sort_column: "name", sort_ascending: true, show_hidden: false })
    property bool memoryLoaded: false
    property bool placed: false
    property var selection: ({})
    property string anchorKey: ""
    property string currentKey: ""
    property var history: []
    property int historyIndex: -1
    property var treeExpanded: ({})
    property bool treeWanted: true
    property bool addressForced: false
    property string dropTargetKey: ""

    readonly property string theme: app.theme
    readonly property bool memphis: theme === "memphis"
    readonly property string locationKey: Model.key(location)
    readonly property var listing: app.store.state.listings[locationKey] || null
    readonly property var connection: Model.hostName(location) ? (app.store.state.connections[Model.hostName(location)] || null) : null
    readonly property var banner: Model.hostBanner(connection, theme)
    readonly property bool greyed: banner.kind === "reconnecting" || banner.kind === "connecting"
    readonly property bool inTrash: Model.placeType(location) === "trash"
    readonly property bool canWrite: !Model.isVirtual(location) && listing !== null && listing.status !== "error"
    readonly property var allEntries: listing ? listing.entries : []
    readonly property int hiddenCount: allEntries.filter(function(e) { return e.hidden; }).length
    readonly property var entries: {
        const shown = Model.visibleEntries(allEntries, memory.show_hidden);
        if (Model.placeType(location) === "computer") return Model.computerOrder(shown);
        return Model.sortEntries(shown, memory.sort_column, memory.sort_ascending, theme);
    }
    readonly property var selectedEntries: entries.filter(function(e) { return win.selection[Model.key(e.location)] === true; })
    readonly property var currentEntry: {
        for (const e of entries) if (Model.key(e.location) === currentKey) return e;
        return null;
    }
    readonly property var plan: LayoutPlan.folderPlan(theme, width, height, { treeWanted: treeWanted, addressForced: addressForced })
    readonly property Item popupOverlay: scale.Overlay.overlay
    readonly property real actualDpr: metrics.devicePixelRatio

    title: Model.windowTitle(location, theme, app.hostname)
    flags: Qt.Window | Qt.FramelessWindowHint
    width: memphis ? 640 : 520
    height: memphis ? 440 : 340
    minimumWidth: 180
    minimumHeight: 120
    color: memphis ? MemphisTokens.face : PlatinumTokens.menuSurface
    background: null

    function raiseWindow() {
        if (visibility === Window.Minimized) showNormal();
        raise();
        requestActivate();
    }

    // ---- loading and memory ----
    // Lists the folder and its view memory once per location.
    property string loadedKey: ""
    function load() {
        if (loadedKey === locationKey) return;
        loadedKey = locationKey;
        selection = {};
        currentKey = "";
        anchorKey = "";
        app.store.list(location);
        memoryLoaded = false;
        const forKey = locationKey;
        app.store.send({ command: "load-view", location: location }, function(event) {
            if (event.event !== "view" || forKey !== win.locationKey) return;
            win.applyMemory(event.view);
        });
    }
    function applyMemory(view) {
        const first = !win.placed && !win.memoryLoaded && history.length <= 1;
        memory = view;
        memoryLoaded = true;
        if (first && view.geometry) {
            width = Math.max(minimumWidth, view.geometry.width);
            height = Math.max(minimumHeight, view.geometry.height);
            if (active) placeNow();
        }
    }
    function placeNow() {
        if (placed || !memory.geometry) return;
        placed = true;
        FilesBridge.placeWindow(title, JSON.stringify(memory.geometry));
    }
    // Saves size, position (from Hyprland when it runs), view and sort.
    function saveMemory() {
        saveTimer.stop();
        if (!memoryLoaded) return;
        let geometry = { x: memory.geometry ? memory.geometry.x : 0, y: memory.geometry ? memory.geometry.y : 0,
            width: Math.round(width), height: Math.round(height) };
        const actual = FilesBridge.windowGeometry(title);
        if (actual !== "") {
            const g = JSON.parse(actual);
            geometry = { x: g.x, y: g.y, width: Math.round(width), height: Math.round(height) };
        }
        const next = Object.assign({}, memory, { geometry: geometry });
        memory = next;
        app.store.send({ command: "save-view", location: location, view: next });
    }
    function setMemory(changes) {
        memory = Object.assign({}, memory, changes);
        saveTimer.restart();
    }
    Timer { id: saveTimer; interval: 600; onTriggered: win.saveMemory() }
    onWidthChanged: if (memoryLoaded && visible) saveTimer.restart()
    onHeightChanged: if (memoryLoaded && visible) saveTimer.restart()
    onActiveChanged: if (active) placeNow()
    onClosing: saveMemory()

    // Memphis navigates in place, with Back and Forward.
    function navigate(next) {
        if (Model.same(next, location)) return;
        saveMemory();
        history = history.slice(0, historyIndex + 1).concat([next]);
        historyIndex = history.length - 1;
        location = next;
        expandTo(next);
    }
    function goHistory(step) {
        const i = historyIndex + step;
        if (i < 0 || i >= history.length) return;
        saveMemory();
        historyIndex = i;
        location = history[i];
        expandTo(location);
    }
    function expandTo(target) {
        const next = Object.assign({}, treeExpanded);
        next[Model.key(Model.computer())] = true;
        for (const a of Model.ancestors(target).slice(0, -1)) next[Model.key(a)] = true;
        treeExpanded = next;
    }
    function toggleTree(target) {
        const k = Model.key(target);
        const next = Object.assign({}, treeExpanded);
        if (next[k]) delete next[k];
        else {
            next[k] = true;
            if (!app.store.state.listings[k]) app.store.list(target);
        }
        treeExpanded = next;
    }
    onLocationChanged: load()
    Component.onCompleted: {
        history = [location];
        historyIndex = 0;
        expandTo(location);
        load();
        if (memphis) app.store.list(Model.computer());
    }

    // A host that comes back lists again; one that was waiting for trust too.
    Connections {
        target: win.app.store
        function onEventReceived(event) {
            if (event.event === "connection" && event.host === Model.hostName(win.location)
                && event.state.state === "connected" && (!win.listing || win.listing.status !== "ready"))
                win.app.store.list(win.location);
        }
    }

    // ---- selection ----
    function isSelected(entry) { return selection[Model.key(entry.location)] === true; }
    function indexOfKey(k) {
        for (let i = 0; i < entries.length; i++) if (Model.key(entries[i].location) === k) return i;
        return -1;
    }
    function select(entry, modifiers) {
        const k = Model.key(entry.location);
        // Memphis: Ctrl toggles, Shift extends. Platinum: Shift toggles
        // (Control-click is the contextual menu).
        const toggle = memphis ? (modifiers & Model.CONTROL) : (modifiers & Model.SHIFT);
        const range = memphis && (modifiers & Model.SHIFT) && anchorKey !== "";
        let next = {};
        if (range) {
            const a = indexOfKey(anchorKey), b = indexOfKey(k);
            for (let i = Math.min(a, b); i <= Math.max(a, b); i++) next[Model.key(entries[i].location)] = true;
        } else if (toggle) {
            next = Object.assign({}, selection);
            if (next[k]) delete next[k]; else next[k] = true;
            anchorKey = k;
        } else {
            next[k] = true;
            anchorKey = k;
        }
        selection = next;
        currentKey = k;
    }
    function pressSelect(entry, modifiers) {
        // A press on a selected item keeps the selection for a drag.
        if (isSelected(entry) && !(modifiers & (Model.SHIFT | Model.CONTROL))) { currentKey = Model.key(entry.location); return; }
        select(entry, modifiers);
    }
    function selectAll() {
        const next = {};
        for (const e of entries) next[Model.key(e.location)] = true;
        selection = next;
    }
    function invertSelection() {
        const next = {};
        for (const e of entries) if (!isSelected(e)) next[Model.key(e.location)] = true;
        selection = next;
    }
    function clearSelection() { selection = {}; }
    function moveCurrent(step, extend) {
        if (!entries.length) return;
        let i = indexOfKey(currentKey);
        i = i < 0 ? 0 : Math.max(0, Math.min(entries.length - 1, i + step));
        select(entries[i], extend ? Model.SHIFT : 0);
    }

    // ---- actions ----
    function activate(entry, modifiers) {
        // Platinum: Option-double-click closes the parent window.
        app.openEntry(entry, win, !memphis && (modifiers & Model.ALT));
    }
    function openSelection(modifiers) {
        for (const e of selectedEntries) activate(e, modifiers || 0);
    }
    function newFolder() {
        if (!canWrite) return;
        let name = "untitled folder", n = 2;
        if (memphis) name = "New Folder";
        const taken = {};
        for (const e of allEntries) taken[e.name] = true;
        const base = name;
        while (taken[name]) name = base + " " + n++;
        app.store.send({ command: "new-folder", parent: location, name: name });
    }
    function trashSelection(permanent) {
        if (inTrash) return app.confirmPermanent(selectedEntries.map(function(e) { return e.location; }),
            selectedEntries.map(function(e) { return e.name; }), "", win);
        app.trashEntries(selectedEntries, win, permanent === true);
    }
    function showOpenWith(entry) {
        app.store.send({ command: "list-handlers", location: Model.openTarget(entry) }, function(event) {
            if (event.event !== "handlers") return;
            const items = event.handlers.map(function(h) {
                return { text: h.name + (h.is_default ? " (default)" : ""), action: "open-with", data: { location: event.location, desktop_id: h.desktop_id } };
            });
            if (!items.length) items.push({ text: "No other applications", enabled: false });
            win.popup(items, win.width / 3, win.height / 3, "Open With");
        });
    }
    function refresh() { app.store.list(location); }

    function reconnect() {
        const h = Model.hostName(location);
        if (h) app.store.send({ command: "connect", host: h });
        refresh();
    }
    function sortBy(column) {
        if (memory.sort_column === column) setMemory({ sort_ascending: !memory.sort_ascending });
        else setMemory({ sort_column: column, sort_ascending: true });
    }

    function act(action, data) {
        const one = selectedEntries.length === 1 ? selectedEntries[0] : null;
        switch (action) {
        case "open": return openSelection(0);
        case "open-with-menu": if (one) showOpenWith(one); return;
        case "open-with": app.store.send({ command: "open-with", location: data.location, desktop_id: data.desktop_id }); return;
        case "close": return close();
        case "new-folder": return newFolder();
        case "info": for (const e of selectedEntries) app.openInfo(e); if (!selectedEntries.length) app.openInfo(Model.placeEntry(location, theme, app.hostname)); return;
        case "rename": if (one) app.openInfo(one).focusName(); return;
        case "trash": return trashSelection(false);
        case "delete-permanently": return trashSelection(true);
        case "restore": return app.restore(selectedEntries);
        case "empty-trash": return app.emptyTrash(win);
        case "eject": if (one) app.eject(one, win); return;
        case "enclosing": return app.openEnclosing(win, false);
        case "cut": return app.copyEntries(selectedEntries, true);
        case "copy": return app.copyEntries(selectedEntries, false);
        case "paste": return app.paste(location);
        case "select-all": return selectAll();
        case "invert-selection": return invertSelection();
        case "view-icons": return setMemory({ view: "icons" });
        case "view-list": return setMemory({ view: "list" });
        case "sort": return setMemory({ sort_column: data, sort_ascending: data === "modified" || data === "size" ? (memphis ? true : false) : true });
        case "reverse": return setMemory({ sort_ascending: !memory.sort_ascending });
        case "hidden": return setMemory({ show_hidden: !memory.show_hidden });
        case "tree": treeWanted = !treeWanted; return;
        case "refresh": return refresh();
        case "reconnect": return reconnect();
        case "back": return goHistory(-1);
        case "forward": return goHistory(1);
        case "up": return app.openEnclosing(win, false);
        case "address": addressForced = true; Qt.callLater(function() { if (frame.item && frame.item.focusAddress) frame.item.focusAddress(); }); return;
        case "go": return app.openLocation(data, { from: win });
        case "transfers": return app.showTransfers();
        }
    }

    // ---- menus (inside the window: there is no global menu bar) ----
    readonly property bool hasSelection: selectedEntries.length > 0
    readonly property bool oneSelected: selectedEntries.length === 1
    readonly property bool volumeSelected: oneSelected && selectedEntries[0].kind === "volume"
    readonly property bool fileSelected: oneSelected && !Model.isContainer(selectedEntries[0])
    readonly property bool deletable: hasSelection && selectedEntries.every(function(e) {
        return ["computer", "volume", "ssh-hosts", "host", "trash"].indexOf(e.kind) < 0; })
    // Home, as the Computer window lists it.
    readonly property var homeLocation: {
        const l = app.store.state.listings[Model.key(Model.computer())];
        if (!l) return null;
        for (const e of l.entries) if (e.icon && e.icon.name === "user-home") return e.location;
        return null;
    }
    function sortEntry(text, column) { return { text: text, action: "sort", data: column, checked: memory.sort_column === column }; }
    function menus() {
        const sep = { separator: true };
        if (!memphis) return [
            { id: "file", title: "File", entries: [
                { text: "New Folder", action: "new-folder", shortcut: "Ctrl-N", enabled: canWrite },
                { text: "Open", action: "open", shortcut: "Ctrl-O", enabled: hasSelection },
                { text: "Open With\u2026", action: "open-with-menu", enabled: fileSelected },
                { text: "Close Window", action: "close", shortcut: "Ctrl-W" }, sep,
                { text: "Get Info", action: "info", shortcut: "Ctrl-I" }, sep,
                { text: "Move to Trash", action: "trash", shortcut: "Ctrl-Del", enabled: deletable && !inTrash },
                { text: "Put Away", action: "restore", shortcut: "Ctrl-Y", enabled: inTrash && hasSelection },
                { text: "Delete Immediately\u2026", action: "delete-permanently", enabled: deletable }, sep,
                { text: "Open Enclosing Folder", action: "enclosing", shortcut: "Ctrl-Up", enabled: Model.parent(location) !== null },
                { text: "Eject", action: "eject", shortcut: "Ctrl-E", enabled: volumeSelected }] },
            { id: "edit", title: "Edit", entries: [
                { text: "Undo", action: "undo", shortcut: "Ctrl-Z", enabled: false }, sep,
                { text: "Cut", action: "cut", shortcut: "Ctrl-X", enabled: false },
                { text: "Copy", action: "copy", shortcut: "Ctrl-C", enabled: hasSelection },
                { text: "Paste", action: "paste", shortcut: "Ctrl-V", enabled: canWrite }, sep,
                { text: "Select All", action: "select-all", shortcut: "Ctrl-A", enabled: entries.length > 0 }] },
            { id: "view", title: "View", entries: [
                { text: "as Icons", action: "view-icons", checked: memory.view !== "list" },
                { text: "as List", action: "view-list", checked: memory.view === "list" }, sep,
                sortEntry("by Name", "name"), sortEntry("by Date", "modified"), sortEntry("by Size", "size"), sortEntry("by Kind", "kind"),
                { text: "Reverse Order", action: "reverse", checked: !memory.sort_ascending }, sep,
                { text: "Show Hidden Files", action: "hidden", checked: memory.show_hidden }] },
            { id: "special", title: "Special", entries: [
                { text: "Empty Trash\u2026", action: "empty-trash", enabled: app.store.state.trash.length > 0 },
                { text: "Eject", action: "eject", enabled: volumeSelected }, sep,
                { text: "Show Transfers", action: "transfers" },
                { text: "Reconnect", action: "reconnect", enabled: Model.isRemote(location) }] }
        ];
        return [
            { id: "file", title: "File", entries: [
                { text: "Open", action: "open", bold: true, enabled: hasSelection },
                { text: "Open With\u2026", action: "open-with-menu", enabled: fileSelected }, sep,
                { text: "New Folder", action: "new-folder", enabled: canWrite }, sep,
                { text: "Delete", action: "trash", shortcut: "Del", enabled: deletable },
                { text: "Rename", action: "rename", shortcut: "F2", enabled: oneSelected && deletable },
                { text: "Properties", action: "info", shortcut: "Alt+Enter" }, sep,
                { text: "Empty Recycle Bin", action: "empty-trash", enabled: app.store.state.trash.length > 0 },
                { text: "Restore", action: "restore", enabled: inTrash && hasSelection },
                { text: "Eject", action: "eject", enabled: volumeSelected }, sep,
                { text: "Close", action: "close" }] },
            { id: "edit", title: "Edit", entries: [
                { text: "Undo", action: "undo", shortcut: "Ctrl+Z", enabled: false }, sep,
                { text: "Cut", action: "cut", shortcut: "Ctrl+X", enabled: deletable },
                { text: "Copy", action: "copy", shortcut: "Ctrl+C", enabled: hasSelection },
                { text: "Paste", action: "paste", shortcut: "Ctrl+V", enabled: canWrite }, sep,
                { text: "Select All", action: "select-all", shortcut: "Ctrl+A", enabled: entries.length > 0 },
                { text: "Invert Selection", action: "invert-selection", enabled: entries.length > 0 }] },
            { id: "view", title: "View", entries: [
                { text: "Folders", action: "tree", checked: treeWanted }, sep,
                { text: "Large Icons", action: "view-icons", checked: memory.view !== "list" },
                { text: "Details", action: "view-list", checked: memory.view === "list" }, sep,
                sortEntry("Arrange by Name", "name"), sortEntry("Arrange by Type", "kind"), sortEntry("Arrange by Size", "size"), sortEntry("Arrange by Date", "modified"), sep,
                { text: "Show all files", action: "hidden", checked: memory.show_hidden }, sep,
                { text: "Refresh", action: "refresh", shortcut: "F5" }] },
            { id: "go", title: "Go", entries: [
                { text: "Back", action: "back", shortcut: "Alt+Left", enabled: historyIndex > 0 },
                { text: "Forward", action: "forward", shortcut: "Alt+Right", enabled: historyIndex < history.length - 1 },
                { text: "Up One Level", action: "up", shortcut: "Backspace", enabled: Model.parent(location) !== null }, sep,
                { text: "Address\u2026", action: "address" }, sep,
                { text: "My Computer", action: "go", data: Model.computer() },
                { text: "Home", action: "go", data: homeLocation, enabled: homeLocation !== null },
                { text: "Network Neighborhood", action: "go", data: Model.sshHosts() },
                { text: "Recycle Bin", action: "go", data: Model.trash() }] },
            { id: "tools", title: "Tools", entries: [
                { text: "Transfers\u2026", action: "transfers" },
                { text: "Reconnect", action: "reconnect", enabled: Model.isRemote(location) }] }
        ];
    }
    function itemMenu(entry) {
        const sep = { separator: true };
        const container = Model.isContainer(entry);
        if (!memphis) return [
            { text: "Open", action: "open" },
            { text: "Open With\u2026", action: "open-with-menu", enabled: !container && oneSelected },
            { text: "Get Info", action: "info" }, sep,
            { text: inTrash ? "Put Away" : "Move to Trash", action: inTrash ? "restore" : "trash", enabled: deletable },
            { text: "Copy", action: "copy" },
            { text: "Eject", action: "eject", enabled: volumeSelected }];
        return [
            { text: "Open", action: "open", bold: true },
            { text: "Open With\u2026", action: "open-with-menu", enabled: !container && oneSelected }, sep,
            { text: "Cut", action: "cut", enabled: deletable },
            { text: "Copy", action: "copy" }, sep,
            { text: inTrash ? "Restore" : "Delete", action: inTrash ? "restore" : "trash", enabled: deletable },
            { text: "Rename", action: "rename", enabled: oneSelected && deletable },
            { text: "Eject", action: "eject", enabled: volumeSelected }, sep,
            { text: "Properties", action: "info" }];
    }
    function backgroundMenu() {
        const sep = { separator: true };
        if (!memphis) return [
            { text: "New Folder", action: "new-folder", enabled: canWrite },
            { text: "Paste", action: "paste", enabled: canWrite }, sep,
            { text: "as Icons", action: "view-icons", checked: memory.view !== "list" },
            { text: "as List", action: "view-list", checked: memory.view === "list" },
            { text: "Show Hidden Files", action: "hidden", checked: memory.show_hidden }, sep,
            { text: "Get Info", action: "info" }];
        return [
            { text: "Large Icons", action: "view-icons", checked: memory.view !== "list" },
            { text: "Details", action: "view-list", checked: memory.view === "list" }, sep,
            sortEntry("Arrange by Name", "name"), sortEntry("Arrange by Type", "kind"), sortEntry("Arrange by Size", "size"), sortEntry("Arrange by Date", "modified"), sep,
            { text: "Refresh", action: "refresh" }, sep,
            { text: "Paste", action: "paste", enabled: canWrite },
            { text: "New Folder", action: "new-folder", enabled: canWrite }, sep,
            { text: "Properties", action: "info" }];
    }
    function popup(entries, x, y, name) {
        menu.entries = entries;
        menu.name = name || "";
        menu.openAtPoint(x, y);
    }
    function contextMenu(entry, x, y) {
        if (entry && !isSelected(entry)) select(entry, 0);
        if (!entry) clearSelection();
        popup(entry ? itemMenu(entry) : backgroundMenu(), x, y, entry ? Model.entryName(entry, theme) : title);
    }

    // ---- drag and drop ----
    // Starts a native drag of the selection. Remote files begin downloading
    // now (Prepare); another app receives their paths at the drop.
    function beginDrag(sourceItem, button) {
        const items = selectedEntries;
        if (!items.length) return;
        const locations = items.map(function(e) { return e.location; });
        const offer = app.prepareOffer(locations);
        app.internalDrop = false;
        FilesNative.startDrag(sourceItem, offer.urls, JSON.stringify(locations), offer.pending, button, items.length);
        // Dropped inside Files: the service copies directly; the download
        // for another app is not needed.
        if (app.internalDrop && offer.pending) app.store.cancelTransfer(offer.pending);
    }
    function dropSources(drop) {
        let locations = [];
        if (drop.formats.indexOf(FilesNative.locationsMime) >= 0) {
            app.internalDrop = true;
            try { locations = JSON.parse(drop.getDataAsString(FilesNative.locationsMime)); } catch (e) { locations = []; }
        }
        if (!locations.length && drop.hasUrls) locations = Model.urlsToLocations(drop.urls.map(String));
        return locations;
    }
    function dropActionFor(sources, destination) {
        return Model.dropAction(theme, sources, destination, FilesNative.keyboardModifiers(),
            FilesNative.dragButton === "right" ? "right" : "left", app.store.state.volumes);
    }
    // Returns the Qt drop action to report back to the drag source.
    function dropInto(destination, drop, x, y) {
        const sources = dropSources(drop);
        const action = dropActionFor(sources, destination);
        const internal = drop.formats.indexOf(FilesNative.locationsMime) >= 0;
        if (action === "none" || !sources.length) return Qt.IgnoreAction;
        if (action === "trash") {
            app.trashEntries(sources.map(function(l) { return { location: l, name: Model.basename(l.path), kind: "file" }; }), win, false);
            return internal ? Qt.MoveAction : Qt.CopyAction;
        }
        if (action === "menu") {
            popup([
                { text: "Move Here", action: "drop-move", bold: true, data: { sources: sources, destination: destination } },
                { text: "Copy Here", action: "drop-copy", data: { sources: sources, destination: destination } },
                { separator: true },
                { text: "Cancel", action: "drop-cancel" }], x, y, "Drop");
            return Qt.CopyAction;
        }
        app.store.transfer(sources, destination, action);
        // Another app never deletes its originals because of a Files drop.
        return internal && action === "move" ? Qt.MoveAction : Qt.CopyAction;
    }

    // ---- keys ----
    Shortcut { sequence: "Ctrl+W"; onActivated: win.close() }
    Shortcut { sequence: "Ctrl+A"; onActivated: win.selectAll() }
    Shortcut { sequence: "Ctrl+C"; onActivated: win.act("copy") }
    Shortcut { sequence: "Ctrl+V"; onActivated: win.act("paste") }
    Shortcut { sequence: "Ctrl+X"; enabled: win.memphis; onActivated: win.act("cut") }
    Shortcut { sequence: "Ctrl+I"; enabled: !win.memphis; onActivated: win.act("info") }
    Shortcut { sequence: "Ctrl+N"; enabled: !win.memphis; onActivated: win.act("new-folder") }
    Shortcut { sequence: "Ctrl+O"; onActivated: win.act("open") }
    Shortcut { sequence: "Ctrl+Down"; enabled: !win.memphis; onActivated: win.openSelection(0) }
    Shortcut { sequence: "Ctrl+Alt+Down"; enabled: !win.memphis; onActivated: win.openSelection(Model.ALT) }
    // Cmd-Up opens the enclosing folder; Cmd-Option-Up also closes this one.
    Shortcut { sequence: "Ctrl+Up"; enabled: !win.memphis; onActivated: win.app.openEnclosing(win, false) }
    Shortcut { sequence: "Ctrl+Alt+Up"; enabled: !win.memphis; onActivated: win.app.openEnclosing(win, true) }
    Shortcut { sequences: ["Ctrl+Backspace", "Ctrl+Del"]; enabled: !win.memphis; onActivated: win.act("trash") }
    Shortcut { sequence: "Ctrl+E"; enabled: !win.memphis; onActivated: win.act("eject") }
    Shortcut { sequence: "Ctrl+Y"; enabled: !win.memphis; onActivated: win.act("restore") }
    Shortcut { sequence: "Del"; enabled: win.memphis; onActivated: win.act("trash") }
    Shortcut { sequence: "Shift+Del"; enabled: win.memphis; onActivated: win.act("delete-permanently") }
    Shortcut { sequence: "Backspace"; enabled: win.memphis; onActivated: win.app.openEnclosing(win, false) }
    Shortcut { sequence: "F2"; enabled: win.memphis; onActivated: win.act("rename") }
    Shortcut { sequence: "F5"; onActivated: win.refresh() }
    Shortcut { sequences: ["Alt+Return", "Alt+Enter"]; enabled: win.memphis; onActivated: win.act("info") }
    Shortcut { sequence: "Alt+Left"; enabled: win.memphis; onActivated: win.goHistory(-1) }
    Shortcut { sequence: "Alt+Right"; enabled: win.memphis; onActivated: win.goHistory(1) }

    WindowScale {
        id: scale
        anchors.fill: parent
        devicePixelRatio: metrics.devicePixelRatio
        NativeWindowMetrics { id: metrics }
        Loader {
            id: frame
            objectName: "folderFrame"
            anchors.fill: parent
            focus: true
            sourceComponent: win.memphis ? memphisFrame : platinumFrame
        }
        Component { id: platinumFrame; PlatinumFolderFrame { window: win } }
        Component { id: memphisFrame; MemphisExplorerFrame { window: win } }
        WindowEdges { anchors.fill: parent; window: win }
    }

    FilesMenu {
        id: menu
        objectName: "windowMenu"
        owner: win
        onChosen: function(action, data) {
            if (action === "drop-move") win.app.store.transfer(data.sources, data.destination, "move");
            else if (action === "drop-copy") win.app.store.transfer(data.sources, data.destination, "copy");
            else if (action !== "drop-cancel") win.act(action, data);
        }
    }
}
