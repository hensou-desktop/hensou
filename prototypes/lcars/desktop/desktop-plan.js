// PROTOTYPE — the desktop frame as a pure function of one screen's size.
// Every threshold is a guess until measured on Myoko and the tablet.
.pragma library

function plan(w, h, primary) {
    var armW = Math.round(Math.max(150, Math.min(230, w * 0.11)));
    var topH = h >= 900 ? 40 : 34;          // top bar: pages, alerts, clock
    var bottomH = h >= 900 ? 30 : 26;       // bottom bar: system readouts
    var gap = 10;                           // Hyprland gaps_out
    var blockH = h >= 900 ? 54 : 46;        // one window block in the arm
    var elbowH = topH + 46;
    var room = h - elbowH - bottomH - 46 - 3 * 4;
    return {
        armW: armW, topH: topH, bottomH: bottomH, gap: gap, blockH: blockH,
        elbowW: armW + 70, elbowH: elbowH, bottomElbowH: bottomH + 46,
        // Window blocks that fit in the arm; the rest fold into one "More" block.
        blocksFit: Math.max(1, Math.floor(room / (blockH + 4)) - 1),
        work: { x: armW + gap + 4, y: topH + gap, w: w - armW - 2 * gap - 4, h: h - topH - bottomH - 2 * gap },
        clock: primary,      // one clock per desktop, on the primary screen
        readouts: primary
    };
}
