.pragma library
// Files' layout decisions as pure functions of the window's own size
// (logical px). Thresholds are guesses, proved at +/- 1 in
// tests/files/layout.test.js; revisit them against Myoko captures.
//
// The ladder: inline, then reflow, then overflow. Nothing is removed:
// every toolbar action is also in a menu, every hidden column's value is in
// Get Info, the tree's places are in the Go menu, and menu titles that do
// not fit move whole into the overflow title.

var TREE_MIN_WINDOW = 460;     // Memphis tree pane shows from this width
var TREE_MIN = 140;
var TREE_MAX = 260;
var TOOLBAR_MIN_HEIGHT = 220;  // Memphis toolbar row
var ADDRESS_MIN_HEIGHT = 250;  // Memphis address row
var STATUS_MIN_HEIGHT = 170;   // status bar / Platinum header strip
var NAME_MIN = 150;            // the list's name column never goes below
var COLUMNS = [                // yield order: the last one goes first
    { id: "modified", width: 190 },
    { id: "size", width: 90 },
    { id: "kind", width: 140 }
];
var SIDE_BY_SIDE = 760;        // transfers beside working copies

function folderPlan(theme, width, height, options) {
    var o = options || {};
    var win98 = theme === "win98";
    var treeWanted = win98 && o.treeWanted !== false;
    var treeShown = treeWanted && width >= TREE_MIN_WINDOW;
    var treeWidth = treeShown ? Math.max(TREE_MIN, Math.min(TREE_MAX, Math.round(width * 0.32))) : 0;
    var contentWidth = width - treeWidth;
    return {
        treeShown: treeShown,
        treeWidth: treeWidth,
        toolbar: win98 && height >= TOOLBAR_MIN_HEIGHT,
        address: win98 && (height >= ADDRESS_MIN_HEIGHT || o.addressForced === true),
        status: height >= STATUS_MIN_HEIGHT,
        columns: listColumns(contentWidth - (o.scrollBar || 0)),
        gap: Math.max(4, Math.min(12, Math.floor(Math.min(width, height) / 40)))
    };
}

// The detail columns that fit beside the name, in display order.
function listColumns(width) {
    var shown = [];
    var used = NAME_MIN;
    for (var i = 0; i < COLUMNS.length; i++) {
        if (used + COLUMNS[i].width > width) break;
        used += COLUMNS[i].width;
        shown.push(COLUMNS[i].id);
    }
    return shown;
}

// How many items fit in a row (menu titles, toolbar buttons). Returns the
// inline count; the rest overflow behind one control of overflowWidth.
function fit(widths, room, overflowWidth) {
    var total = 0;
    for (var i = 0; i < widths.length; i++) total += widths[i];
    if (total <= room) return widths.length;
    var used = overflowWidth;
    for (var j = 0; j < widths.length; j++) {
        if (used + widths[j] > room) return j;
        used += widths[j];
    }
    return widths.length;
}

function columnWidth(id) {
    for (var i = 0; i < COLUMNS.length; i++) if (COLUMNS[i].id === id) return COLUMNS[i].width;
    return 0;
}

// Icon grid: cells per row from the width, never fewer than one.
function gridColumns(width, cell) {
    return Math.max(1, Math.floor(width / Math.max(1, cell)));
}

function transfersPlan(width, height) {
    return {
        sideBySide: width >= SIDE_BY_SIDE,
        // A short window still shows both lists; each scrolls.
        compactRows: height < 260
    };
}
