.pragma library
// Files' view model: pure functions over files-model JSON (the serde format
// of crates/files-model). No Qt objects; tests/files/model.test.js runs it.
// Theme ids are "platinum" and "win98" (Memphis).

// ---- modifiers (Qt::KeyboardModifier values) ----
var SHIFT = 0x02000000;
var CONTROL = 0x04000000;
var ALT = 0x08000000;

// ---- locations ----
function local(path) { return { place: { type: "local" }, path: path }; }
function host(name, path) { return { place: { type: "host", name: name }, path: path || "/" }; }
function computer() { return { place: { type: "computer" }, path: "" }; }
function sshHosts() { return { place: { type: "ssh-hosts" }, path: "" }; }
function trash() { return { place: { type: "trash" }, path: "" }; }

function key(location) {
    if (!location || !location.place) return "";
    var p = location.place;
    return p.type + (p.type === "host" ? ":" + p.name : "") + ":" + (location.path || "");
}
function same(a, b) { return key(a) === key(b); }
function placeType(location) { return location && location.place ? location.place.type : ""; }
function hostName(location) { return placeType(location) === "host" ? location.place.name : ""; }
function isVirtual(location) { var t = placeType(location); return t === "computer" || t === "ssh-hosts" || t === "trash"; }
function isRemote(location) { return placeType(location) === "host"; }

function basename(path) {
    var trimmed = String(path || "").replace(/\/+$/, "");
    var i = trimmed.lastIndexOf("/");
    return i < 0 ? trimmed : trimmed.slice(i + 1);
}
function dirname(path) {
    var trimmed = String(path || "").replace(/\/+$/, "");
    var i = trimmed.lastIndexOf("/");
    return i <= 0 ? "/" : trimmed.slice(0, i);
}
function child(location, name) {
    var base = location.path === "/" ? "" : location.path;
    return { place: location.place, path: base + "/" + name };
}
// The enclosing folder (Cmd-Up, Up One Level). The top of a disk or host
// goes to the Computer window or the SSH Hosts folder.
function parent(location) {
    var t = placeType(location);
    if (t === "local") return location.path === "/" || location.path === "" ? computer() : local(dirname(location.path));
    if (t === "host") return location.path === "/" || location.path === "" ? sshHosts() : host(location.place.name, dirname(location.path));
    if (t === "ssh-hosts" || t === "trash") return computer();
    return null;
}
// Ancestors from the top, for the Memphis address and tree.
function ancestors(location) {
    var out = [];
    for (var l = location; l; l = parent(l)) out.unshift(l);
    return out;
}
function contains(outer, inner) {
    if (!outer || !inner || placeType(outer) !== placeType(inner) || hostName(outer) !== hostName(inner)) return false;
    if (isVirtual(outer)) return false;
    var o = outer.path === "/" ? "" : outer.path;
    return inner.path === outer.path || inner.path.indexOf(o + "/") === 0;
}

// ---- names and titles ----
function computerName(theme, hostname) { return theme === "win98" ? "My Computer" : (hostname || "Computer"); }
function sshHostsName(theme) { return theme === "win98" ? "Network Neighborhood" : "SSH Hosts"; }
function trashName(theme) { return theme === "win98" ? "Recycle Bin" : "Trash"; }

function locationName(location, theme, hostname) {
    var t = placeType(location);
    if (t === "computer") return computerName(theme, hostname);
    if (t === "ssh-hosts") return sshHostsName(theme);
    if (t === "trash") return trashName(theme);
    if (t === "host") return location.path === "/" || location.path === "" ? location.place.name : basename(location.path);
    if (location.path === "/") return "/";
    return basename(location.path);
}
function windowTitle(location, theme, hostname) {
    var name = locationName(location, theme, hostname);
    return theme === "win98" && !isVirtual(location) ? "Exploring - " + name : name;
}
// The Memphis address bar, and what it accepts back.
function addressText(location, theme, hostname) {
    if (isVirtual(location)) return locationName(location, theme, hostname);
    if (isRemote(location)) return location.place.name + ":" + location.path;
    return location.path;
}
function parseAddress(text, theme, hostname) {
    var t = String(text || "").trim();
    if (t === "") return null;
    var lower = t.toLowerCase();
    if (lower === computerName(theme, hostname).toLowerCase() || lower === "computer:") return computer();
    if (lower === sshHostsName(theme).toLowerCase()) return sshHosts();
    if (lower === trashName(theme).toLowerCase() || lower === "trash:") return trash();
    var m = /^(?:sftp|ssh):\/\/(?:[^@/]*@)?([^:/]+)(?::\d+)?(\/.*)?$/.exec(t);
    if (m) return host(m[1], m[2] || "/");
    if (lower.indexOf("file://") === 0) return local(decodeURIComponent(t.slice(7)) || "/");
    m = /^([A-Za-z0-9._-]+):(\/.*)?$/.exec(t);
    if (m) return host(m[1], m[2] || "/");
    if (t[0] === "/") return local(t);
    return null;
}

function entryName(entry, theme) {
    if (entry.kind === "ssh-hosts") return sshHostsName(theme);
    if (entry.kind === "trash") return trashName(theme);
    return entry.name;
}

// ---- kinds ----
var MIME_KINDS = {
    "text-plain": ["text document", "Text Document"],
    "application-pdf": ["Portable Document Format file", "PDF Document"],
    "image-jpeg": ["JPEG image", "JPEG Image"],
    "image-png": ["PNG image", "PNG Image"],
    "audio-mpeg": ["MP3 audio file", "MP3 Audio"],
    "video-x-matroska": ["Matroska video", "Matroska Video"],
    "application-zip": ["ZIP archive", "Compressed (zipped) Folder"],
    "application-gzip": ["gzip archive", "GZ File"],
    "application-x-cd-image": ["disk image", "Disc Image File"],
    "application-x-shellscript": ["shell script", "Shell Script"],
    "application-octet-stream": ["document", "File"]
};
function kindText(entry, theme) {
    var w = theme === "win98";
    switch (entry.kind) {
    case "folder": return w ? "File Folder" : "folder";
    case "alias": return w ? "Shortcut" : "alias";
    case "launcher": return w ? "Application" : "application program";
    case "computer": return w ? "System Folder" : "computer";
    case "volume": return w ? "Removable Disk" : "disk";
    case "ssh-hosts": return w ? "System Folder" : "folder";
    case "host": return w ? "Network Computer" : "SSH host";
    case "trash": return w ? "Recycle Bin" : "Trash";
    }
    var name = entry.icon ? entry.icon.name : "";
    if (MIME_KINDS[name]) return MIME_KINDS[name][w ? 1 : 0];
    var dot = entry.name.lastIndexOf(".");
    if (dot > 0) return w ? entry.name.slice(dot + 1).toUpperCase() + " File" : "document";
    return w ? "File" : "document";
}

// Theme art names (Art.js). No thumbnails: kinds only.
function artName(entry) {
    switch (entry.kind) {
    case "folder": return entry.icon && entry.icon.name === "user-home" ? "home" : "folder";
    case "computer": return "computer";
    case "volume": return "removable";
    case "ssh-hosts": return "network";
    case "host": return "host";
    case "trash": return "trash";
    case "launcher": return "application";
    case "alias": return entry.icon && entry.icon.name === "folder" ? "folder" : "document";
    }
    var name = entry.icon ? entry.icon.name : "";
    if (name === "user-home") return "home";
    if (name === "folder") return "folder";
    if (name.indexOf("text-") === 0 || name === "application-x-shellscript") return "text";
    if (name.indexOf("image-") === 0) return "image";
    if (name.indexOf("audio-") === 0) return "audio";
    if (name.indexOf("video-") === 0) return "video";
    if (/zip|gzip|tar|compressed|x-cd-image|bzip|xz/.test(name)) return "archive";
    if (name === "application-pdf") return "document";
    if (entry.mode !== null && entry.mode !== undefined && (entry.mode & 0o111) && entry.kind === "file") return "application";
    return "document";
}

// Can the entry be opened as a folder window?
function isContainer(entry) {
    if (entry.kind === "alias") return !!entry.link_target && entry.icon && entry.icon.name === "folder";
    return ["folder", "computer", "volume", "ssh-hosts", "host", "trash"].indexOf(entry.kind) >= 0;
}
// Where an open goes. Opening an alias follows its link.
function openTarget(entry) {
    if (entry.kind === "alias" && entry.link_target) {
        var target = entry.link_target;
        if (target[0] !== "/") target = dirname(entry.location.path) + "/" + target;
        return { place: entry.location.place, path: target };
    }
    return entry.location;
}

// ---- values ----
function group(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ","); }
function oneDecimal(v) { return v >= 100 ? String(Math.round(v)) : (Math.round(v * 10) / 10).toFixed(1).replace(/\.0$/, ""); }

// A size in a column. Unknown is never 0: "--" in Platinum (Mac OS lists
// folders that way) and empty in Memphis (Explorer leaves folders blank),
// with "Unknown" for files whose size is not known.
function sizeText(size, theme, entry) {
    var w = theme === "win98";
    if (size === null || size === undefined) {
        if (entry && entry.kind !== "file") return w ? "" : "--";
        return w ? "Unknown" : "--";
    }
    if (w) return group(size === 0 ? 0 : Math.max(1, Math.ceil(size / 1024))) + "KB";
    if (size < 1024) return size + (size === 1 ? " byte" : " bytes");
    if (size < 1024 * 1024) return group(Math.round(size / 1024)) + " K";
    if (size < 1024 * 1024 * 1024) return oneDecimal(size / 1048576) + " MB";
    if (size < 1024 * 1024 * 1024 * 1024) return oneDecimal(size / 1073741824) + " GB";
    return oneDecimal(size / 1099511627776) + " TB";
}
// Get Info / Properties: both the short and the exact value.
function sizeInfo(size, theme) {
    if (size === null || size === undefined) return "Unknown";
    var unit = size < 1024 ? size + " bytes"
        : size < 1048576 ? oneDecimal(size / 1024) + (theme === "win98" ? "KB" : " K")
        : size < 1073741824 ? oneDecimal(size / 1048576) + (theme === "win98" ? "MB" : " MB")
        : size < 1099511627776 ? oneDecimal(size / 1073741824) + (theme === "win98" ? "GB" : " GB")
        : oneDecimal(size / 1099511627776) + (theme === "win98" ? "TB" : " TB");
    return size < 1024 ? unit : unit + " (" + group(size) + " bytes)";
}

var DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
var MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
function pad(n) { return n < 10 ? "0" + n : String(n); }
// style: "column" (short) or "info" (long). Unknown dates say so.
function dateText(seconds, theme, style) {
    if (seconds === null || seconds === undefined) return theme === "win98" ? "Unknown" : "--";
    var d = new Date(seconds * 1000);
    var h = d.getHours(), m = pad(d.getMinutes());
    var h12 = (h % 12) || 12, ampm = h < 12 ? "AM" : "PM";
    if (theme === "win98") {
        if (style === "info") return DAYS[d.getDay()] + ", " + MONTHS[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear() + " " + h12 + ":" + m + ":" + pad(d.getSeconds()) + " " + ampm;
        return (d.getMonth() + 1) + "/" + d.getDate() + "/" + String(d.getFullYear()).slice(2) + " " + h12 + ":" + m + " " + ampm;
    }
    if (style === "info") return DAYS[d.getDay()] + ", " + MONTHS[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear() + ", " + h12 + ":" + m + " " + ampm;
    return MONTHS[d.getMonth()].slice(0, 3) + " " + d.getDate() + ", " + d.getFullYear() + ", " + h12 + ":" + m + " " + ampm;
}

function permissionsText(mode) {
    if (mode === null || mode === undefined) return "Unknown";
    var out = "";
    var marks = "rwxrwxrwx";
    for (var i = 0; i < 9; i++) out += (mode & (1 << (8 - i))) ? marks[i] : "-";
    return out + " (" + (mode & 0o777).toString(8) + ")";
}
// Locked (Platinum) and Read-only (Memphis) are the absence of write bits.
function isLocked(mode) {
    if (mode === null || mode === undefined) return false;
    return (mode & 0o222) === 0;
}

// ---- listings ----
function visibleEntries(entries, showHidden) {
    return (entries || []).filter(function(e) { return showHidden || !e.hidden; });
}
function compareText(a, b) {
    var x = String(a).toLowerCase(), y = String(b).toLowerCase();
    return x < y ? -1 : x > y ? 1 : 0;
}
var KIND_ORDER = { computer: 0, volume: 1, folder: 2, "ssh-hosts": 3, host: 3, trash: 4 };
// Explorer lists folders before files; the Finder mixes them by name.
function sortEntries(entries, column, ascending, theme) {
    var dir = ascending === false ? -1 : 1;
    var foldersFirst = theme === "win98";
    var list = (entries || []).slice();
    list.sort(function(a, b) {
        if (foldersFirst) {
            var fa = isContainer(a) ? 0 : 1, fb = isContainer(b) ? 0 : 1;
            if (fa !== fb) return fa - fb;
        }
        var c = 0;
        if (column === "size") {
            var sa = a.size === null || a.size === undefined ? -1 : a.size;
            var sb = b.size === null || b.size === undefined ? -1 : b.size;
            c = sa - sb;
        } else if (column === "modified") {
            c = (a.modified || 0) - (b.modified || 0);
        } else if (column === "kind") {
            c = compareText(kindText(a, theme), kindText(b, theme));
        }
        if (c === 0) c = compareText(a.name, b.name);
        return c * dir;
    });
    return list;
}
// The Computer window keeps its own order: Home, volumes, hosts, Trash.
function computerOrder(entries) {
    var rank = function(e) { return e.kind === "folder" ? 0 : e.kind === "volume" ? 1 : e.kind === "ssh-hosts" ? 2 : e.kind === "trash" ? 3 : 4; };
    return (entries || []).slice().sort(function(a, b) { return rank(a) - rank(b) || compareText(a.name, b.name); });
}

// ---- drag and drop ----
// The disk a location lives on: its host, the volume whose mount point
// holds it, or the local system disk.
function diskOf(location, volumes) {
    var t = placeType(location);
    if (t === "host") return "host:" + location.place.name;
    if (t !== "local") return "";
    var best = "";
    for (var i = 0; i < (volumes || []).length; i++) {
        var mount = volumes[i].mount_point;
        if (mount && (location.path === mount || location.path.indexOf(mount.replace(/\/$/, "") + "/") === 0) && mount.length > best.length)
            best = mount;
    }
    return "local:" + (best || "/");
}
// What a drop does: "move", "copy", "menu" (Memphis right-drag), "trash"
// or "none". Same disk moves; another disk or host copies. Platinum:
// Option (Alt) forces a copy. Memphis: Ctrl forces a copy, Shift a move.
function dropAction(theme, sources, destination, modifiers, button, volumes) {
    if (!destination || !sources || sources.length === 0) return "none";
    var t = placeType(destination);
    if (t === "trash") return "trash";
    if (t === "computer" || t === "ssh-hosts") return "none";
    for (var i = 0; i < sources.length; i++) {
        if (contains(sources[i], destination)) return "none";
    }
    var allHere = sources.every(function(s) { return same(parent(s), destination); });
    if (theme === "win98") {
        if (button === "right") return "menu";
        if (modifiers & CONTROL) return "copy";
        if (modifiers & SHIFT) return allHere ? "none" : "move";
    } else if (modifiers & ALT) {
        return "copy";
    }
    if (allHere) return "none";
    var disk = diskOf(destination, volumes);
    var sameDisk = sources.every(function(s) { return diskOf(s, volumes) === disk; });
    return sameDisk ? "move" : "copy";
}
// file:// URLs from another app as locations.
function urlsToLocations(urls) {
    var out = [];
    for (var i = 0; i < (urls || []).length; i++) {
        var u = String(urls[i]);
        if (u.indexOf("file://") !== 0) continue;
        var path = u.slice(7);
        var slash = path.indexOf("/");
        if (slash < 0) continue;
        out.push(local(decodeURIComponent(path.slice(slash))));
    }
    return out;
}
function fileUrl(path) {
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
}

// ---- transfers ----
var ACTIVE = ["queued", "running", "waiting-for-host", "ask-keep-waiting", "conflict"];
function transferActive(t) { return ACTIVE.indexOf(t.state.state) >= 0; }
function transferNeedsChoice(t) { return t.state.state === "conflict" || t.state.state === "ask-keep-waiting"; }
function plural(n, one, many) { return n + " " + (n === 1 ? one : many); }
function quote(name, theme) { return theme === "win98" ? name : "\u201c" + name + "\u201d"; }
function transferTitle(t, theme, hostname) {
    var verb = t.mode === "move" ? "Moving" : "Copying";
    var count = t.items_total !== null && t.items_total !== undefined ? t.items_total : t.sources.length;
    var what = count === 1 && t.sources.length === 1 ? quote(basename(t.sources[0].path), theme) : plural(count, "item", "items");
    return verb + " " + what + " to " + quote(locationName(t.destination, theme, hostname), theme);
}
// 0..1, or -1 when nothing about the size is known (an indeterminate bar).
function transferProgress(t) {
    if (t.state.state === "done") return 1;
    if (t.bytes_total) return Math.max(0, Math.min(1, t.bytes_done / t.bytes_total));
    if (t.items_total) return Math.max(0, Math.min(1, t.items_done / t.items_total));
    return -1;
}
function transferDetail(t, theme) {
    var s = t.state;
    var bytes = t.bytes_total !== null && t.bytes_total !== undefined
        ? sizeInfoShort(t.bytes_done) + " of " + sizeInfoShort(t.bytes_total)
        : sizeInfoShort(t.bytes_done) + " of unknown size";
    switch (s.state) {
    case "queued": return "Waiting to start";
    case "running": return (t.current ? basename(t.current.path) + ": " : "") + bytes;
    case "waiting-for-host": return "Waiting for " + s.host + " to reconnect. " + bytes + " copied; it continues from there.";
    case "ask-keep-waiting": return s.host + " has been offline for 10 minutes.";
    case "conflict": return "An item named " + quote(s.conflict.source.name, theme) + " already exists in this location.";
    case "done": return "Done";
    case "failed": return "Failed: " + s.reason;
    case "cancelled": return "Cancelled";
    }
    return "";
}
function sizeInfoShort(n) {
    if (n === null || n === undefined) return "unknown";
    if (n < 1024) return n + " bytes";
    if (n < 1048576) return oneDecimal(n / 1024) + " KB";
    if (n < 1073741824) return oneDecimal(n / 1048576) + " MB";
    return oneDecimal(n / 1073741824) + " GB";
}
// The StatusNotifierItem: present while transfers run.
function trayState(transfers) {
    var active = [], attention = false;
    for (var id in transfers) {
        var t = transfers[id];
        if (transferActive(t)) active.push(t);
        if (transferNeedsChoice(t)) attention = true;
    }
    var tip = active.length === 0 ? "" : active.length === 1 ? transferTitle(active[0], "platinum", "") : plural(active.length, "transfer", "transfers") + " in progress";
    if (attention) tip += active.length ? ". A transfer needs a choice." : "";
    return { active: active.length > 0, attention: attention, toolTip: tip, count: active.length };
}
function copyStateText(copy) {
    switch (copy.state.state) {
    case "watching": return "Watching for saves";
    case "uploading": return "Uploading";
    case "upload-queued": return "Saved while offline; uploads after the reconnect";
    case "remote-changed": return "Changed on the host since it was opened";
    case "failed": return "Upload failed: " + copy.state.reason;
    }
    return "";
}

// ---- connection states ----
// What a window for a host location shows besides its listing.
function hostBanner(connection, theme) {
    if (!connection) return { kind: "none", text: "" };
    switch (connection.state) {
    case "reconnecting": return { kind: "reconnecting", text: "Reconnecting\u2026" };
    case "connecting": return { kind: "connecting", text: "Connecting\u2026" };
    case "failed": return { kind: "failed", text: "Cannot connect: " + connection.reason };
    case "host-key-changed": return { kind: "refused", text: "Not connected: this host's identity has changed." };
    }
    return { kind: "none", text: "" };
}

// ---- the store ----
function emptyState() {
    return { hosts: [], connections: {}, volumes: [], trash: [], transfers: {}, copies: {}, listings: {}, requests: {}, info: {} };
}
function assign(base, changes) {
    var out = {};
    for (var k in base) out[k] = base[k];
    for (var c in changes) out[c] = changes[c];
    return out;
}
function withKey(map, k, value) {
    var out = assign(map, {});
    if (value === undefined) delete out[k];
    else out[k] = value;
    return out;
}
// Remember what a request was for, so its errors land in the right place.
function noteRequest(state, id, info) {
    return assign(state, { requests: withKey(state.requests, String(id), info) });
}
function markLoading(state, location) {
    var k = key(location);
    var old = state.listings[k];
    // Only a folder that was listed refreshes; anything else is still loading.
    var refreshing = old && (old.status === "ready" || old.status === "refreshing");
    return assign(state, { listings: withKey(state.listings, k, { status: refreshing ? "refreshing" : "loading", entries: old ? old.entries : [], error: null }) });
}
function errorText(error) {
    switch (error.kind) {
    case "not-found": return "The item could not be found.";
    case "permission-denied": return "You do not have permission to open it.";
    case "already-exists": return "An item with that name already exists.";
    case "volume-busy": return "The disk is in use by " + error.holders.join(", ") + ".";
    case "host-unreachable": return error.host + " cannot be reached.";
    case "host-key-rejected": return "The host key of " + error.host + " was not trusted.";
    case "unsupported": return "This is not supported: " + error.what + ".";
    case "other": return error.message;
    }
    return "Something went wrong.";
}
function reduce(state, event) {
    switch (event.event) {
    case "listing":
    case "folder-changed":
        return assign(state, { listings: withKey(state.listings, key(event.location), { status: "ready", entries: event.entries, error: null }) });
    case "hosts": return assign(state, { hosts: event.names });
    case "connection": return assign(state, { connections: withKey(state.connections, event.host, event.state) });
    case "volumes": return assign(state, { volumes: event.volumes });
    case "trash": return assign(state, { trash: event.items });
    case "transfer": return assign(state, { transfers: withKey(state.transfers, String(event.transfer.id), event.transfer) });
    case "working-copy": return assign(state, { copies: withKey(state.copies, key(event.copy.remote), event.copy) });
    case "working-copy-removed": return assign(state, { copies: withKey(state.copies, key(event.remote), undefined) });
    case "info": return assign(state, { info: withKey(state.info, key(event.entry.location), event.entry) });
    case "error":
        var note = event.request !== null && event.request !== undefined ? state.requests[String(event.request)] : null;
        if (note && note.kind === "list") {
            var old = state.listings[note.key];
            return assign(state, { listings: withKey(state.listings, note.key, { status: "error", entries: old ? old.entries : [], error: event.error }) });
        }
        return state;
    }
    return state;
}

// A rejected host key ends every load that waited for that host.
function rejectHost(state, hostname) {
    var listings = state.listings, changed = false, prefix = "host:" + hostname + ":";
    for (var k in listings) {
        if (k.indexOf(prefix) === 0 && (listings[k].status === "loading" || listings[k].status === "refreshing")) {
            listings = withKey(listings, k, { status: "error", entries: listings[k].entries, error: { kind: "host-key-rejected", host: hostname } });
            changed = true;
        }
    }
    return changed ? assign(state, { listings: listings }) : state;
}

// ---- the Memphis folder tree ----
// Visible rows of the tree under My Computer. expanded: key -> true.
// childrenOf(location) returns its known child entries or null (not listed).
function treeRows(roots, expanded, childrenOf, theme, hostname) {
    var rows = [];
    function walk(entry, depth) {
        var loc = entry.kind === "alias" ? openTarget(entry) : entry.location;
        var k = key(loc);
        var kids = childrenOf(loc);
        var folders = kids === null ? null : kids.filter(function(e) { return isContainer(e) && !e.hidden && e.kind !== "alias"; });
        var open = !!expanded[k];
        rows.push({ key: k, location: loc, name: entryName(entry, theme), art: artName(entry), depth: depth, expanded: open,
            expandable: folders === null ? entry.kind !== "trash" : folders.length > 0 });
        if (open && folders) {
            var sorted = sortEntries(folders, "name", true, theme);
            for (var i = 0; i < sorted.length; i++) walk(sorted[i], depth + 1);
        }
    }
    for (var i = 0; i < roots.length; i++) walk(roots[i], 0);
    return rows;
}
// A pseudo-entry for a virtual place (the tree root, title icons).
function placeEntry(location, theme, hostname) {
    var t = placeType(location);
    var kind = t === "computer" ? "computer" : t === "ssh-hosts" ? "ssh-hosts" : t === "trash" ? "trash" : t === "host" && (location.path === "/" || location.path === "") ? "host" : "folder";
    return { location: location, name: locationName(location, theme, hostname), kind: kind, size: null, modified: null, hidden: false,
        link_target: null, owner: null, mode: null, icon: { name: kind === "folder" ? "folder" : kind } };
}
