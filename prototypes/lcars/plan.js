// PROTOTYPE — layout as a pure function of the window size (intrinsic-design).
// Every threshold is a guess until measured in a real Hensou window.
.pragma library

var NAV_RAIL_MIN_W = 640;   // below this the host rail folds into one "Hosts" pill
var SHORT_H = 420;          // below this the header band merges into one row
var COL_SIZE_MIN_W = 520;
var COL_DATE_MIN_W = 760;
var COL_KIND_MIN_W = 980;
var PILL_H = 44;

function plan(w, h, hostCount) {
    var short = h < SHORT_H;
    var rail = w >= NAV_RAIL_MIN_W;
    var railW = rail ? Math.round(Math.max(140, Math.min(220, w * 0.16))) : 0;
    var headerH = short ? 40 : Math.round(Math.max(56, Math.min(96, h * 0.11)));
    var footerH = short ? 0 : 28;
    var gap = 4;
    // Host pills that fit in the rail below the elbow; the rest go to "More".
    var railRoom = h - headerH - footerH - 3 * gap - 40;
    var fit = rail ? Math.max(1, Math.floor(railRoom / (PILL_H + gap)) - 1) : 0;
    var inline = Math.min(hostCount, fit);
    if (rail && inline < hostCount) inline = Math.max(0, fit - 1); // leave room for More
    return {
        short: short,
        rail: rail,
        railW: railW,
        headerH: headerH,
        footerH: footerH,
        pillH: short ? 32 : PILL_H,
        hostsInline: rail ? inline : 0,
        hostsOverflow: rail ? hostCount - inline : hostCount,
        // Actions (Up, New folder, Connect) move whole into one "Actions" pill.
        actionsInline: w >= 900,
        showSize: w >= COL_SIZE_MIN_W,
        showDate: w >= COL_DATE_MIN_W,
        showKind: w >= COL_KIND_MIN_W,
        // Miller columns for variant C: one column per 300 px, at least 1.
        millerCols: Math.max(1, Math.min(3, Math.floor((w - 16) / 300))),
        titlePx: short ? 26 : Math.round(Math.max(30, Math.min(64, headerH * 0.72))),
        rowPx: short ? 18 : 20
    };
}
