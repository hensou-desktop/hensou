.pragma library
// The words and buttons of every Files alert, per theme. Pure: tests read
// the defaults from here (Cancel is the default wherever data is at risk).
// A spec: { art, title, message, detail, buttons: [{ text, action }],
// defaultAction, cancelAction }. Platinum alerts have no title bar text;
// Memphis message boxes have a caption.

function q(name, theme) { return theme === "win98" ? name : "\u201c" + name + "\u201d"; }
function itemsWord(n) { return n === 1 ? "1 item" : n + " items"; }

function hostKey(prompt, theme) {
    var w = theme === "win98";
    return {
        kind: "host-key",
        art: "key",
        title: w ? "Unknown Host Key" : "",
        message: w ? "Files has not connected to " + prompt.host + " before." : "The identity of " + q(prompt.host, theme) + " is not known.",
        detail: "Connect only if this fingerprint matches the one the host's owner gave you.",
        fingerprint: prompt.algorithm + "  " + prompt.fingerprint,
        buttons: [{ text: "Connect", action: "trust" }, { text: "Cancel", action: "reject" }],
        defaultAction: "reject",
        cancelAction: "reject"
    };
}

function changedKey(host, fingerprint, theme) {
    var w = theme === "win98";
    return {
        kind: "changed-key",
        art: w ? "error" : "stop",
        title: w ? "Host Identity Changed" : "",
        message: w ? "Files did not connect to " + host + ", because its identity has changed."
            : "The identity of " + q(host, theme) + " has changed. Files did not connect.",
        detail: "The key it presented is not the one you trusted before. Someone may be intercepting the connection. If the host was reinstalled, remove its old key from ~/.ssh/known_hosts, then open it again.",
        fingerprint: fingerprint,
        buttons: [{ text: "OK", action: "ok" }],
        defaultAction: "ok",
        cancelAction: "ok"
    };
}

// Memphis only: Explorer asks before the Recycle Bin. Platinum does not.
function moveToTrash(names, theme) {
    var one = names.length === 1;
    return {
        kind: "move-to-trash",
        art: "question",
        title: one ? "Confirm File Delete" : "Confirm Multiple File Delete",
        message: one ? "Are you sure you want to send " + q(names[0], theme) + " to the Recycle Bin?"
            : "Are you sure you want to send these " + names.length + " items to the Recycle Bin?",
        detail: "",
        buttons: [{ text: "Yes", action: "trash" }, { text: "No", action: "cancel" }],
        defaultAction: "trash",
        cancelAction: "cancel"
    };
}

// Both themes warn before anything that cannot be undone.
function deletePermanently(names, reason, theme) {
    var w = theme === "win98", one = names.length === 1;
    var what = one ? q(names[0], theme) : itemsWord(names.length);
    return {
        kind: "delete-permanently",
        art: w ? "warning" : "caution",
        title: w ? (one ? "Confirm File Delete" : "Confirm Multiple File Delete") : "",
        message: w ? "Are you sure you want to permanently delete " + (one ? what : "these " + what) + "?"
            : what + (one ? " will" : " will") + " be deleted immediately. You cannot undo this action.",
        detail: (reason ? reason + " " : "") + (w ? "It will not go to the Recycle Bin and cannot be restored." : "It does not go to the Trash."),
        buttons: w ? [{ text: "Yes", action: "delete" }, { text: "No", action: "cancel" }]
            : [{ text: "Delete", action: "delete" }, { text: "Cancel", action: "cancel" }],
        defaultAction: "cancel",
        cancelAction: "cancel"
    };
}

function sizeWords(bytes) {
    if (bytes === null || bytes === undefined) return "";
    if (bytes < 1024) return bytes + " bytes";
    if (bytes < 1048576) return Math.round(bytes / 1024) + " K";
    return (Math.round(bytes / 104857.6) / 10) + " MB";
}

function emptyTrash(count, bytes, theme) {
    var w = theme === "win98";
    var known = bytes !== null && bytes !== undefined;
    return {
        kind: "empty-trash",
        art: w ? "warning" : "caution",
        title: w ? "Confirm Multiple File Delete" : "",
        message: w ? "Are you sure you want to delete " + (count === 1 ? "the item" : "all " + count + " items") + " in the Recycle Bin?"
            : "The Trash contains " + itemsWord(count) + (known ? ", which use " + sizeWords(bytes) + " of disk space" : "") + ". Are you sure you want to permanently remove " + (count === 1 ? "it" : "these items") + "?",
        detail: "You cannot undo this action.",
        buttons: w ? [{ text: "Yes", action: "empty" }, { text: "No", action: "cancel" }]
            : [{ text: "OK", action: "empty" }, { text: "Cancel", action: "cancel" }],
        defaultAction: "cancel",
        cancelAction: "cancel"
    };
}

function ejectBusy(name, holders, theme) {
    var w = theme === "win98";
    var who = holders && holders.length ? holders.join(", ") : "another program";
    return {
        kind: "eject-busy",
        art: w ? "warning" : "caution",
        title: w ? "Problem Ejecting Device" : "",
        message: w ? "Files cannot eject " + name + " now, because it is in use."
            : "The disk " + q(name, theme) + " could not be put away, because it contains items that are in use.",
        detail: "In use by: " + who + ". Close " + (holders && holders.length === 1 ? "it" : "them") + ", then try again.",
        buttons: [{ text: "OK", action: "ok" }],
        defaultAction: "ok",
        cancelAction: "ok"
    };
}

function failure(text, theme) {
    var w = theme === "win98";
    return {
        kind: "failure",
        art: w ? "error" : "stop",
        title: w ? "Error" : "",
        message: "The operation could not be completed.",
        detail: text,
        buttons: [{ text: "OK", action: "ok" }],
        defaultAction: "ok",
        cancelAction: "ok"
    };
}
