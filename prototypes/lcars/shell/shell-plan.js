// PROTOTYPE — the LCARS shell as pure functions of one screen's size.
// Mirrors the live Platinum bar's rules (modules/quickshell/bar-plan.js):
// a control's value shows only while it warns; controls never vanish, they
// move into "More" in OVERFLOW_ORDER. Thresholds are guesses.
.pragma library

var OVERFLOW_ORDER = ["oci", "disk", "fleet", "builder", "layout", "bri", "bt", "wifi", "ntf", "vol"];
var GAP = 4;

function frame(w, h) {
    var armW = Math.round(Math.max(150, Math.min(240, w * 0.115)));
    var topH = h >= 900 ? 44 : 36;
    var bottomH = h >= 900 ? 30 : 26;
    var blockH = h >= 900 ? 50 : 42;
    return {
        armW: armW, topH: topH, bottomH: bottomH, blockH: blockH,
        elbowW: armW + 64, elbowH: topH + 44, bottomElbowH: bottomH + 44,
        work: { x: armW + 14, y: topH + 10, w: w - armW - 24, h: h - topH - bottomH - 20 }
    };
}

// controls: [{ id, label, value, warn, w }] in bar order. Returns positions
// (x relative to the bar's left) and which controls went to More.
function bar(barW, controls, clockW, minTitle) {
    var shown = controls.slice();
    var more = [];
    function need() {
        var s = 0;
        for (var i = 0; i < shown.length; i++) s += shown[i].w + GAP;
        return s + (more.length ? 96 + GAP : 0) + clockW + GAP + minTitle;
    }
    for (var k = 0; k < OVERFLOW_ORDER.length && need() > barW; k++) {
        for (var j = 0; j < shown.length; j++)
            if (shown[j].id === OVERFLOW_ORDER[k]) { more.push(shown[j]); shown.splice(j, 1); break; }
    }
    var titleW = barW - need() + minTitle;
    var x = titleW + GAP, pos = [];
    for (var m = 0; m < shown.length; m++) { pos.push({ c: shown[m], x: x }); x += shown[m].w + GAP; }
    var moreX = more.length ? x : -1;
    if (more.length) x += 96 + GAP;
    return { titleW: titleW, segs: pos, more: more, moreX: moreX, clockX: x };
}
