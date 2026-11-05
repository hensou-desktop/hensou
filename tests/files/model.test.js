// Pure Files view model, layout plan and alert wording. Run: node tests/files/model.test.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

function load(path) {
    const context = { encodeURIComponent, decodeURIComponent };
    const source = fs.readFileSync(path, "utf8").replace(/^\.pragma library\s*$/m, "");
    vm.runInNewContext(source, context);
    return context;
}
const Model = load("apps/files/qml/Model.js");
const Plan = load("apps/files/qml/LayoutPlan.js");
const Alerts = load("apps/files/qml/Alerts.js");
const plain = (v) => JSON.parse(JSON.stringify(v));

function entry(path, kind, extra) {
    return Object.assign({ location: Model.local(path), name: path.split("/").pop(), kind: kind || "file", size: 10, modified: 0,
        hidden: path.split("/").pop().startsWith("."), link_target: null, owner: "me", mode: 0o644, icon: { name: "text-plain" } }, extra || {});
}

// ---- locations and names ----
assert.equal(Model.windowTitle(Model.computer(), "platinum", "Myoko"), "Myoko");
assert.equal(Model.windowTitle(Model.computer(), "win98", "Myoko"), "My Computer");
assert.equal(Model.windowTitle(Model.local("/home/fixture/Documents"), "win98", "Myoko"), "Exploring - Documents");
assert.equal(Model.windowTitle(Model.host("fuji", "/"), "platinum", ""), "fuji");
assert.equal(Model.locationName(Model.sshHosts(), "win98"), "Network Neighborhood");
assert.equal(Model.locationName(Model.trash(), "win98"), "Recycle Bin");
assert.deepEqual(plain(Model.parent(Model.local("/home/fixture"))), plain(Model.local("/home")));
assert.deepEqual(plain(Model.parent(Model.local("/"))), plain(Model.computer()));
assert.deepEqual(plain(Model.parent(Model.host("fuji", "/"))), plain(Model.sshHosts()));
assert.equal(Model.parent(Model.computer()), null);
assert.equal(Model.ancestors(Model.local("/home/a")).length, 4);
assert.deepEqual(plain(Model.parseAddress("fuji:/srv/media", "win98", "Myoko")), plain(Model.host("fuji", "/srv/media")));
assert.deepEqual(plain(Model.parseAddress("/home", "win98", "Myoko")), plain(Model.local("/home")));
assert.deepEqual(plain(Model.parseAddress("my computer", "win98", "Myoko")), plain(Model.computer()));
assert.equal(Model.parseAddress("relative/path", "win98", "Myoko"), null);
assert.equal(Model.entryName({ kind: "ssh-hosts", name: "SSH Hosts" }, "win98"), "Network Neighborhood");
console.log("locations, titles and addresses: PASS");

// ---- values: unknown is never 0 ----
assert.equal(Model.sizeText(null, "platinum", entry("/a", "file")), "--");
assert.equal(Model.sizeText(null, "win98", entry("/a", "file")), "Unknown");
assert.equal(Model.sizeText(null, "win98", entry("/a", "folder")), "");
assert.equal(Model.sizeText(0, "platinum"), "0 bytes");
assert.equal(Model.sizeText(0, "win98"), "0KB");
assert.equal(Model.sizeText(1, "win98"), "1KB");
assert.equal(Model.sizeText(3400000, "platinum"), "3.2 MB");
assert.equal(Model.sizeText(5000000000000, "platinum"), "4.5 TB");
assert.equal(Model.sizeInfo(null, "platinum"), "Unknown");
assert.equal(Model.sizeInfo(120000, "win98"), "117KB (120,000 bytes)");
assert.equal(Model.dateText(null, "win98", "column"), "Unknown");
assert.equal(Model.permissionsText(0o644), "rw-r--r-- (644)");
assert.equal(Model.permissionsText(null), "Unknown");
assert.equal(Model.isLocked(0o444), true);
assert.equal(Model.isLocked(0o644), false);
assert.equal(Model.isLocked(null), false);
assert.equal(Model.kindText(entry("/a", "alias"), "platinum"), "alias");
assert.equal(Model.kindText(entry("/a", "alias"), "win98"), "Shortcut");
console.log("sizes, dates, permissions and kinds: PASS");

// ---- listings ----
const listed = [entry("/h/b.txt"), entry("/h/.hidden"), entry("/h/A", "folder", { size: null }), entry("/h/c", "file", { size: null })];
assert.equal(Model.visibleEntries(listed, false).length, 3);
assert.equal(Model.visibleEntries(listed, true).length, 4);
assert.deepEqual(Model.sortEntries(listed, "name", true, "win98").map((e) => e.name), ["A", ".hidden", "b.txt", "c"]);
assert.deepEqual(Model.sortEntries(listed, "size", false, "platinum").map((e) => e.name), ["b.txt", ".hidden", "c", "A"]);
assert.equal(Model.artName(entry("/h/x.jpg", "file", { icon: { name: "image-jpeg" } })), "image");
assert.equal(Model.artName({ kind: "folder", icon: { name: "user-home" } }), "home");
const alias = entry("/h/link", "alias", { link_target: "/h/A", icon: { name: "folder" } });
assert.equal(Model.isContainer(alias), true);
assert.deepEqual(plain(Model.openTarget(alias)), plain(Model.local("/h/A")));
console.log("visibility, sorting, aliases: PASS");

// ---- drag and drop ----
const volumes = [{ id: "usb", label: "USB", mount_point: "/run/media/fixture/USB" }];
const home = Model.local("/home/fixture");
const docs = Model.local("/home/fixture/Documents");
const usb = Model.local("/run/media/fixture/USB");
const file = [Model.local("/home/fixture/notes.txt")];
assert.equal(Model.dropAction("platinum", file, docs, 0, "left", volumes), "move");
assert.equal(Model.dropAction("platinum", file, docs, Model.ALT, "left", volumes), "copy");
assert.equal(Model.dropAction("platinum", file, usb, 0, "left", volumes), "copy");
assert.equal(Model.dropAction("platinum", file, Model.host("fuji", "/srv"), 0, "left", volumes), "copy");
assert.equal(Model.dropAction("win98", file, docs, 0, "left", volumes), "move");
assert.equal(Model.dropAction("win98", file, docs, Model.CONTROL, "left", volumes), "copy");
assert.equal(Model.dropAction("win98", file, usb, Model.SHIFT, "left", volumes), "move");
assert.equal(Model.dropAction("win98", file, usb, 0, "right", volumes), "menu");
assert.equal(Model.dropAction("platinum", file, Model.trash(), 0, "left", volumes), "trash");
assert.equal(Model.dropAction("platinum", [docs], docs, 0, "left", volumes), "none");
assert.equal(Model.dropAction("platinum", [home], docs, 0, "left", volumes), "none");
assert.equal(Model.dropAction("platinum", file, home, 0, "left", volumes), "none");
assert.equal(Model.dropAction("platinum", file, Model.computer(), 0, "left", volumes), "none");
assert.equal(Model.diskOf(Model.local("/run/media/fixture/USB/a"), volumes), "local:/run/media/fixture/USB");
assert.equal(Model.diskOf(Model.local("/run/media/fixture/USB2"), volumes), "local:/");
assert.deepEqual(plain(Model.urlsToLocations(["file:///home/a%20b", "https://x/"])), [plain(Model.local("/home/a b"))]);
console.log("drop rules per theme: PASS");

// ---- store reduction ----
let state = Model.emptyState();
state = Model.markLoading(state, home);
assert.equal(state.listings[Model.key(home)].status, "loading");
state = Model.noteRequest(state, 7, { kind: "list", key: Model.key(home) });
state = Model.reduce(state, { event: "error", request: 7, error: { kind: "permission-denied" } });
assert.equal(state.listings[Model.key(home)].status, "error");
state = Model.reduce(state, { event: "listing", request: 8, location: home, entries: listed });
assert.equal(state.listings[Model.key(home)].status, "ready");
const fuji = Model.host("fuji", "/");
state = Model.markLoading(state, fuji);
state = Model.rejectHost(state, "fuji");
assert.equal(state.listings[Model.key(fuji)].error.kind, "host-key-rejected");
const running = { id: 3, mode: "copy", sources: file, destination: usb, current: null, items_done: 0, items_total: 1, bytes_done: 5, bytes_total: 10, state: { state: "running" } };
state = Model.reduce(state, { event: "transfer", transfer: running });
assert.equal(Model.trayState(state.transfers).active, true);
assert.equal(Model.trayState(state.transfers).attention, false);
assert.equal(Model.transferProgress(running), 0.5);
assert.equal(Model.transferProgress(Object.assign({}, running, { bytes_total: null, items_total: null })), -1);
state = Model.reduce(state, { event: "transfer", transfer: Object.assign({}, running, { state: { state: "conflict", conflict: { source: entry("/a"), existing: entry("/b") } } }) });
assert.equal(Model.trayState(state.transfers).attention, true);
state = Model.reduce(state, { event: "transfer", transfer: Object.assign({}, running, { state: { state: "done" } }) });
assert.equal(Model.trayState(state.transfers).active, false);
const copy = { remote: Model.host("fuji", "/srv/a"), local: "/tmp/a", last_saved: null, state: { state: "watching" } };
state = Model.reduce(state, { event: "working-copy", copy: copy });
assert.equal(Object.keys(state.copies).length, 1);
state = Model.reduce(state, { event: "working-copy-removed", remote: copy.remote });
assert.equal(Object.keys(state.copies).length, 0);
assert.equal(Model.hostBanner({ state: "reconnecting", since: 0, attempt: 2 }).text, "Reconnecting\u2026");
assert.equal(Model.hostBanner({ state: "host-key-changed", fingerprint: "x" }).kind, "refused");
assert.equal(Model.transferTitle(running, "platinum", "Myoko"), "Copying \u201cnotes.txt\u201d to \u201cUSB\u201d");
console.log("store reduction, transfers and the tray: PASS");

// ---- the Memphis tree ----
const computerEntries = [Object.assign(entry("/home/fixture", "folder"), { name: "Home", icon: { name: "user-home" } }),
    { location: Model.sshHosts(), name: "SSH Hosts", kind: "ssh-hosts", hidden: false, icon: { name: "network-workgroup" } },
    { location: Model.trash(), name: "Trash", kind: "trash", hidden: false, icon: { name: "user-trash" } }];
const children = { [Model.key(Model.computer())]: computerEntries, [Model.key(home)]: listed };
const expanded = { [Model.key(Model.computer())]: true, [Model.key(home)]: true };
const rows = Model.treeRows([Model.placeEntry(Model.computer(), "win98", "Myoko")], expanded, (l) => children[Model.key(l)] || null, "win98", "Myoko");
assert.deepEqual(rows.map((r) => r.name), ["My Computer", "Home", "A", "Network Neighborhood", "Recycle Bin"]);
assert.equal(rows[2].depth, 2);
assert.equal(rows[4].expandable, false);
console.log("tree rows: PASS");

// ---- alerts: Cancel is the default where data is at risk ----
for (const theme of ["platinum", "win98"]) {
    const key = Alerts.hostKey({ host: "fuji", algorithm: "ssh-ed25519", fingerprint: "SHA256:abc" }, theme);
    assert.equal(key.defaultAction, "reject");
    assert.equal(key.cancelAction, "reject");
    assert.ok(key.fingerprint.includes("SHA256:abc"));
    assert.deepEqual(key.buttons.map((b) => b.action).sort(), ["reject", "trust"]);
    assert.equal(Alerts.emptyTrash(3, 100, theme).defaultAction, "cancel");
    assert.equal(Alerts.deletePermanently(["a"], "No Trash.", theme).defaultAction, "cancel");
    assert.deepEqual(Alerts.changedKey("nara", "SHA256:x", theme).buttons.map((b) => b.action), ["ok"]);
    assert.ok(Alerts.ejectBusy("USB", ["ghostty"], theme).detail.includes("ghostty"));
}
assert.equal(Alerts.moveToTrash(["a"], "win98").defaultAction, "trash");
assert.ok(Alerts.emptyTrash(3, null, "platinum").message.indexOf("disk space") < 0);
console.log("alert defaults: PASS");

// ---- layout plan: thresholds at +/- 1 ----
for (const [w, shown] of [[459, false], [460, true], [461, true]]) assert.equal(Plan.folderPlan("win98", w, 600).treeShown, shown);
assert.equal(Plan.folderPlan("platinum", 2000, 600).treeShown, false);
assert.equal(Plan.folderPlan("win98", 900, 600, { treeWanted: false }).treeShown, false);
for (const [h, shown] of [[219, false], [220, true], [221, true]]) assert.equal(Plan.folderPlan("win98", 600, h).toolbar, shown);
for (const [h, shown] of [[249, false], [250, true]]) assert.equal(Plan.folderPlan("win98", 600, h).address, shown);
assert.equal(Plan.folderPlan("win98", 600, 140, { addressForced: true }).address, true);
for (const [h, shown] of [[169, false], [170, true]]) assert.equal(Plan.folderPlan("platinum", 600, h).status, shown);
assert.deepEqual(Plan.listColumns(150 + 170 - 1), []);
assert.deepEqual(Plan.listColumns(150 + 170), ["modified"]);
assert.deepEqual(Plan.listColumns(150 + 170 + 80), ["modified", "size"]);
assert.deepEqual(Plan.listColumns(150 + 170 + 80 + 130 - 1), ["modified", "size"]);
assert.deepEqual(Plan.listColumns(150 + 170 + 80 + 130), ["modified", "size", "kind"]);
// Groups move whole; something always overflows behind one control.
assert.equal(Plan.fit([40, 40, 40, 40], 160, 20), 4);
assert.equal(Plan.fit([40, 40, 40, 40], 159, 20), 3);
assert.equal(Plan.fit([40, 40, 40, 40], 59, 20), 0);
assert.equal(Plan.gridColumns(10, 96), 1);
assert.equal(Plan.transfersPlan(759, 400).sideBySide, false);
assert.equal(Plan.transfersPlan(760, 400).sideBySide, true);
console.log("layout plan boundaries: PASS");
