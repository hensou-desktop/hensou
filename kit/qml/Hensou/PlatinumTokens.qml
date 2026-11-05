pragma Singleton
import QtQuick

QtObject {
    id: root
    readonly property bool dark: Theme.dark
    readonly property bool extraDark: Theme.extraDark
    // The unchanged bottom dock uses these Platinum-owned tokens.
    readonly property string fontFamily: "monospace"
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 6
    readonly property color bgPanel: dark ? "#141414" : "#ffffff"
    readonly property color bgActive: dark ? "#303030" : "#dcdcdc"
    readonly property color bgSeparator: dark ? "#3a3a3a" : "#c8c8c8"
    readonly property color accent: dark ? "#6a9fb5" : "#3d7a94"
    readonly property color textSecondary: dark ? "#c0c0c0" : "#303030"

    //----------------------------------------------------------------
    // PLATINUM: the top bar and the menus that open from it.
    //----------------------------------------------------------------
    // Mac OS 8.1, read in a modern way. Light takes the 8.1 values: bar
    // #DDDDDD, a black rule, bevels #FFFFFF/#999999, a #222222 hard
    // shadow and the #333399 highlight. Dark is dark grey Platinum: a
    // #363636 bar on the same black rule, over dark grey menus.
    // Extra dark (dark mode only) makes the bar black with no rule, which
    // keeps the OLED rule above; the menus stay dark grey, because menus
    // are transient and the OLED argument does not apply to them.
    // The dock, the omni bar and the popups keep the tokens above.

    // ChicagoFLF 2.1 is the only face in the bar and its menus. It lacks
    // ● ○ ✓ × the arrows and a lock; those are SVG files in icons/.
    readonly property string platinumFont: "ChicagoFLF"
    readonly property int platinumText: 14      // bar titles, menu rows
    readonly property int platinumSmall: 12     // details, buttons, tabs
    readonly property int platinumHint: 11      // key hints
    readonly property real platinumTracking: 0.3

    // One physical rule at every scale: 2 px at 1.5, 1 px at 1 and 2.
    // Each window supplies its own device pixel ratio through WindowScale;
    // read it with ratioFor and hairFor. pixelRatio and hair are only the
    // fallback for an object outside a window.
    property real pixelRatio: 1.5
    readonly property real hair: Math.max(1, Math.round(pixelRatio)) / pixelRatio

    // Explicit per-window helpers. Legacy scalar properties are fallbacks only.
    function ratioFor(windowOrRatio) {
        const d = typeof windowOrRatio === "number" ? windowOrRatio
            : windowOrRatio ? windowOrRatio.devicePixelRatio : 0;
        return d > 0 ? d : root.pixelRatio;
    }
    function hairFor(windowOrRatio) {
        const d = ratioFor(windowOrRatio);
        return Math.max(1, Math.round(d)) / d;
    }
    function focusRingFor(windowOrRatio) {
        const d = ratioFor(windowOrRatio);
        return Math.max(2, Math.round(2 * d)) / d;
    }
    function snapFor(windowOrRatio, value) {
        const d = ratioFor(windowOrRatio);
        return Math.round(value * d) / d;
    }

    readonly property int barHeight: 28

    //----------------------------------------------------------------
    // APPEARANCES. Platinum has three: Light (Mac OS 8.1's values), Dark
    // grey, and Drawing Board (light only: warm paper, graphite frame
    // lines that run past each corner like drafting crop marks, and a
    // hatched shadow). Extra dark applies to Dark grey only.
    //----------------------------------------------------------------
    readonly property var appearances: [
        { id: "light", label: "Light", dark: false },
        { id: "dark-grey", label: "Dark grey", dark: true },
        { id: "drawing-board", label: "Drawing Board", dark: false }
    ]
    function appearanceInfo(id) {
        for (const a of root.appearances) if (a.id === id) return a;
        return null;
    }
    // Theme.appearance when it names one of ours, else the mode's default.
    // Read defensively: a Theme without the property gives undefined.
    readonly property string appearance: resolve(Theme.appearance, Theme.dark)
    function resolve(id, dark) {
        return typeof id === "string" && root.appearanceInfo(id) ? id : (dark ? "dark-grey" : "light");
    }

    // Every colour the bar, the menus, the dialogs and the strip draw, for
    // one appearance. palette(id, extra) is the one source: the properties
    // below read the current appearance; a preview passes an explicit ID.
    // The bar has three looks in Dark grey: grey, or black with Extra dark.
    function palette(id, extra) {
        const info = root.appearanceInfo(id) || root.appearanceInfo(root.resolve(id, Theme.dark));
        const dark = info.dark;
        const board = info.id === "drawing-board";
        const black = dark && extra === true;
        const p = {
            // The bar surface is one token.
            barSurface: !dark ? (board ? "#e8e2d5" : "#dddddd") : black ? "#000000" : "#363636",
            // The Mac OS 8 rule under the bar. On black there is no rule at
            // all: the bar meets the windows directly, so no lit line stays
            // on screen. Drawing Board's rule is the graphite frame line.
            barRule: board ? "#3b3833" : "#000000",
            barShadowTop: board ? "#2e3b3833" : "#40000000",   // fading to 0
            barText: !dark ? (board ? "#24221e" : "#000000") : black ? "#e6e6e6" : "#ececec",
            barTextSecondary: !dark ? (board ? "#4a463f" : "#3a3a3a") : black ? "#a4a4a4" : "#b8b8b8",
            // About 3:1 on each surface, so a muted readout still reads.
            barTextOff: !dark ? (board ? "#8a8477" : "#8a8a8a") : black ? "#5c5c5c" : "#808080",
            barHover: dark ? "#1fffffff" : "#1a000000",
            barDanger: dark ? "#ef8f8f" : "#9e2525",
            barWarning: dark ? "#d5a66f" : "#7a4d12",
            barButton: !dark ? (board ? "#f3eee4" : "#e6e6e6") : black ? "#262626" : "#444444",
            barButtonEdge: black ? "#8c8c8c" : board ? "#3b3833" : "#000000",

            // The highlight: an open title, a pressed control, a selected
            // row. Drawing Board's is a blueprint blue (white on it 7.4:1).
            highlight: dark ? "#5858d0" : board ? "#3a5784" : "#333399",
            highlightText: "#ffffff",

            menuSurface: dark ? "#3a3a3a" : board ? "#f4efe5" : "#dddddd",
            menuText: dark ? "#ececec" : board ? "#24221e" : "#000000",
            menuTextSecondary: dark ? "#b8b8b8" : board ? "#4a463f" : "#3a3a3a",
            menuTextOff: dark ? "#767676" : board ? "#8a8477" : "#8a8a8a",
            menuEdge: board ? "#3b3833" : "#000000",
            bevelLight: dark ? "#565656" : board ? "#fdfbf6" : "#ffffff",
            bevelDark: dark ? "#1e1e1e" : board ? "#bdb5a6" : "#999999",
            // Light and Dark grey: a solid shadow. Drawing Board: the colour
            // of the hatch lines (frameHatch draws them).
            menuShadow: dark ? "#9e000000" : board ? "#8c8578" : "#222222",
            well: dark ? "#242424" : board ? "#ddd6c8" : "#bdbdbd",
            raised: dark ? "#444444" : board ? "#f8f4ec" : "#e6e6e6",
            // Edit fields and list boxes (the Find menu, Go to Address): a
            // white well in light, a dark one in dark grey, cream paper on
            // the board. Menus and dialogs are transient, so extra dark
            // leaves them dark grey too.
            field: dark ? "#242424" : board ? "#fefcf8" : "#ffffff",
            list: dark ? "#2c2c2c" : board ? "#fefcf8" : "#ffffff",
            // Platinum's default focus ring is lavender (Mac OS 8 HIG): the
            // only ring, around the field that has the keyboard. Drawing
            // Board's is a blue pencil.
            focusRing: dark ? "#7c7ce8" : board ? "#7d98c4" : "#9999ff",
            // Balloon Help: the full text of a row the menu cut off.
            balloon: dark ? "#2c2c2c" : board ? "#fefcf8" : "#ffffff",
            menuDanger: dark ? "#ef8f8f" : "#9e2525",
            menuWarning: dark ? "#d5a66f" : "#7a4d12",
            // A dialog's or windoid's title bar: the menu surface, except on
            // the board, where the paper under the title is a shade deeper.
            titleSurface: dark ? "#3a3a3a" : board ? "#e8e2d5" : "#dddddd",

            // Drawing Board's frame: graphite lines over every edge that
            // run frameOverrun px past each corner, and a hatched shadow
            // frameShadow px down and right. Off elsewhere.
            frameLine: board ? "#3b3833" : "transparent",

            // The Control Strip. On black it is black and flat, with a dim
            // hair edge; the others take the Platinum bevel.
            stripEdge: black ? "#3a3a3a" : board ? "#3b3833" : "#000000",
            tile: !dark ? (board ? "#f3eee4" : "#e6e6e6") : black ? "transparent" : "#444444",
            tileSunk: !dark ? (board ? "#ddd6c8" : "#bdbdbd") : black ? "#262626" : "#242424",
            tileSunkEdge: "#8c8c8c",      // black strip only
            grooveLow: !dark ? (board ? "#bdb5a6" : "#999999") : black ? "#3a3a3a" : "#1e1e1e",
            grooveHigh: !dark ? (board ? "#fdfbf6" : "#ffffff") : black ? "transparent" : "#565656",
            ridgeLow: !dark ? (board ? "#bdb5a6" : "#999999") : black ? "#5c5c5c" : "#1e1e1e",
            ridgeHigh: !dark ? (board ? "#fdfbf6" : "#ffffff") : black ? "transparent" : "#565656"
        };
        p.stripSurface = p.barSurface;
        return p;
    }
    readonly property var current: palette(appearance, extraDark)
    // The names every appearance resolves (tests walk them).
    readonly property var tokenNames: Object.keys(palette("light", false))

    readonly property bool drafting: appearance === "drawing-board"
    readonly property real frameOverrun: drafting ? 7 : 0
    readonly property real frameShadow: drafting ? 5 : 2
    readonly property color frameLine: current.frameLine

    // The bar has three appearances: light, dark grey, and black (extra
    // dark, in dark mode only). Every bar token below picks from them.
    readonly property bool barBlack: dark && extraDark

    readonly property color barSurface: current.barSurface
    readonly property bool barRuled: !barBlack
    readonly property color barRule: current.barRule

    // Depth for the light and grey bars: the raised Platinum bevel (one
    // highlight hair on top, one shade hair just above the rule) and a
    // short shadow cast on what lies under the bar (PlatinumBarShadow).
    // At 1.5 the hairs fall on physical rows 0-1 and 38-39, the rule on
    // 40-41. The black bar has neither, so it stays flat.
    readonly property bool barRaised: barRuled
    readonly property color barBevelLight: bevelLight
    readonly property color barBevelDark: bevelDark
    readonly property int barShadowHeight: 4
    readonly property color barShadowTop: current.barShadowTop
    readonly property color barText: current.barText
    readonly property color barTextSecondary: current.barTextSecondary
    readonly property color barTextOff: current.barTextOff
    readonly property color barHover: current.barHover
    readonly property color barDanger: current.barDanger
    readonly property color barWarning: current.barWarning
    // Bar buttons (dictation Retry and Dismiss). Light and grey bars give
    // them the Platinum bevel. On black they lose it, which would read as
    // noise there.
    readonly property bool barBevelled: !barBlack
    readonly property color barButton: current.barButton
    readonly property color barButtonEdge: current.barButtonEdge

    readonly property color highlight: current.highlight
    readonly property color highlightText: current.highlightText

    readonly property color menuSurface: current.menuSurface
    readonly property color menuText: current.menuText
    readonly property color menuTextSecondary: current.menuTextSecondary
    readonly property color menuTextOff: current.menuTextOff
    readonly property color menuEdge: current.menuEdge
    readonly property color bevelLight: current.bevelLight
    readonly property color bevelDark: current.bevelDark
    readonly property color menuShadow: current.menuShadow
    readonly property color well: current.well
    readonly property color raised: current.raised
    readonly property color field: current.field
    readonly property color list: current.list
    readonly property color focusRing: current.focusRing
    readonly property real focusRingWidth: Math.max(2, Math.round(2 * pixelRatio)) / pixelRatio
    readonly property color balloon: current.balloon
    readonly property color menuDanger: current.menuDanger
    readonly property color menuWarning: current.menuWarning
    readonly property color titleSurface: current.titleSurface

    // The menu grid. Every menu has the same three columns:
    //   gutter  marks (● ○ ✓), checkbox boxes, icons; centred on one line
    //   text    every label, title, section, detail and hint starts here
    //   right   every value and the last button end here
    // A menu whose list scrolls moves its right edge in by the scroll bar,
    // for every row at once, so the column stays one line.
    readonly property int menuGutter: 6          // gutter's left edge
    readonly property int menuGutterWidth: 20
    readonly property int menuTextLeft: 30
    readonly property int menuRightInset: 12
    readonly property int menuScrollBar: 16
    readonly property int menuGap: 8             // between items in a row
    readonly property int menuButtonHeight: 22
    readonly property int menuLine: 26           // one-line row
    readonly property int menuRow: 40            // two-line row

    //----------------------------------------------------------------
    // THE CONTROL STRIP (bottom left) and its windoids.
    //----------------------------------------------------------------
    // The strip stays on screen for hours, so on the black bar it is black
    // and flat too, with a dim hair edge; the light and grey strips take
    // the Platinum bevel. Geometry lives in themes/platinum/strip-plan.js.
    readonly property color stripSurface: current.stripSurface
    readonly property color stripEdge: current.stripEdge
    readonly property bool stripBevelled: !barBlack
    readonly property color tile: current.tile
    readonly property color tileSunk: current.tileSunk
    readonly property color tileSunkEdge: current.tileSunkEdge
    readonly property color grooveLow: current.grooveLow
    readonly property color grooveHigh: current.grooveHigh
    readonly property color ridgeLow: current.ridgeLow
    readonly property color ridgeHigh: current.ridgeHigh

    // Motion that answers a gesture (the strip scrolling) turns off here.
    // Nothing in the session publishes reduced motion yet.
    property bool reducedMotion: false

    // A length on whole physical pixels, so hairs and stipples stay crisp
    // at fractional scales.
    function snap(v) { return Math.round(v * root.pixelRatio) / root.pixelRatio; }

    // A tone word from the models (battery.js, oci-model.js,
    // notification-model.js) as a colour. Unknown words read as normal.
    function barTone(tone) {
        if (tone === "danger") return root.barDanger;
        if (tone === "warning") return root.barWarning;
        if (tone === "muted" || tone === "off") return root.barTextOff;
        if (tone === "quiet") return root.barTextSecondary;
        return root.barText;
    }

    function menuTone(tone) {
        if (tone === "danger") return root.menuDanger;
        if (tone === "warning") return root.menuWarning;
        if (tone === "muted" || tone === "off") return root.menuTextSecondary;
        return root.menuText;
    }
}
