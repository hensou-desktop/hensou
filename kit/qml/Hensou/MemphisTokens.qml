pragma Singleton

import QtQuick

// The Memphis theme's tokens: the unit, the two appearances, the font
// and the metrics every Memphis control shares.
//
// The unit. One Memphis pixel ("u") is two physical pixels, so every bevel
// line is exactly 1 u and lands on whole physical pixels. At Myoko's scale
// 1.5, 1 u = 4/3 logical px. All geometry is whole units: never centre
// with anchors.centerIn on an odd remainder, use snap(). It rounds a half
// unit down the screen and to the right, as the mock's browser snapped
// every box and every text baseline to its CSS pixel (1 u), so the Qt
// controls land on the same pixels as the approved mock.
//
// The appearance follows Theme.appearance (falling back from Theme.mode):
// Standard (sampled from screenshots of the original), Dark grey (the approved
// mock's ramp) and 20 colour schemes from the classic system colours. All
// keep the same order of light and dark edges.
QtObject {
    id: root

    // The unit belongs to each window: 2 physical px at that window's own
    // device pixel ratio. Every control reads it through unitFor(QsWindow
    // .window), so a taskbar on a scale-1 screen and one on a scale-1.5
    // screen each draw 2-px bevels. pixelRatio and u are only the fallback
    // for an object outside a window (a Scope).
    property real pixelRatio: 1.5
    readonly property real u: 2 / pixelRatio
    function unitFor(w) {
        return w && w.devicePixelRatio > 0 ? 2 / w.devicePixelRatio : root.u;
    }

    // No roll-out when true. The host sets it; nothing in the session
    // publishes a reduced-motion preference yet.
    property bool reducedMotion: false
    readonly property int rollDuration: reducedMotion ? 0 : 120

    function px(n, unit) { return n * (unit || root.u); }
    // To the whole unit; a half goes up (down the screen, to the right).
    function snap(v, unit) { const k = unit || root.u; return Math.floor(v / k + 0.5 + 1e-6) * k; }
    // To the half unit: one physical pixel. The mock's browser centred boxes
    // and text runs across (horizontally) without snapping them to a unit;
    // a half unit still lands on whole physical pixels.
    function half(v, unit) { const k = (unit || root.u) / 2; return Math.round(v / k + 1e-6) * k; }
    // Up to a whole unit, for sizes measured from text.
    function ceilU(v, unit) { const k = unit || root.u; return Math.ceil(v / k - 1e-6) * k; }

    readonly property bool dark: Theme.dark

    // ---- appearances. Memphis has 22: Standard and Dark grey, Hensou's own
    // (below), and 20 colour schemes taken from the classic system colours.
    // id is the saved, stable kebab-case value (Theme.appearance); dark is
    // the mode the host derives from it. The labels are user-visible text.
    readonly property var appearances: [
        { id: "standard", label: "Standard", dark: false },
        { id: "dark-grey", label: "Dark grey", dark: true },
        { id: "brick", label: "Brick", dark: false },
        { id: "desert", label: "Desert", dark: false },
        { id: "eggplant", label: "Eggplant", dark: false },
        { id: "lilac", label: "Lilac", dark: false },
        { id: "maple", label: "Maple", dark: false },
        { id: "marine", label: "Marine", dark: false },
        { id: "plum", label: "Plum", dark: false },
        { id: "pumpkin", label: "Pumpkin", dark: false },
        { id: "rainy-day", label: "Rainy Day", dark: false },
        { id: "red-white-blue", label: "Red, White and Blue", dark: false },
        { id: "rose", label: "Rose", dark: false },
        { id: "slate", label: "Slate", dark: false },
        { id: "spruce", label: "Spruce", dark: false },
        { id: "storm", label: "Storm", dark: false },
        { id: "teal", label: "Teal", dark: false },
        { id: "wheat", label: "Wheat", dark: false },
        { id: "high-contrast-black", label: "High Contrast Black", dark: true },
        { id: "high-contrast-white", label: "High Contrast White", dark: false },
        { id: "high-contrast-1", label: "High Contrast #1", dark: true },
        { id: "high-contrast-2", label: "High Contrast #2", dark: true }
    ]
    function appearanceInfo(id) {
        for (const a of root.appearances) if (a.id === id) return a;
        return null;
    }
    // The appearance on screen: Theme.appearance when it names one of ours,
    // else the mode's default (light: Standard, dark: Dark grey). An
    // unknown ID falls back the same way; the stored value is the host's.
    // Read defensively: a Theme without the property gives undefined.
    readonly property string appearance: resolve(Theme.appearance, Theme.dark)
    function resolve(id, dark) {
        return typeof id === "string" && root.appearanceInfo(id) ? id : (dark ? "dark-grey" : "standard");
    }

    // The schemes' system colours, verbatim and keyed by the system colour
    // names (Control, ControlDark, ...). Source: the zaxbux gist "System
    // Colours (by OS)", its classic scheme set without the visual styles,
    // as extracted to system-colour-schemes.json. Brick was cross-checked
    // against ReactOS boot/bootdata/hivedef.inf: every value matched. That
    // these equal the older release's schemes is inferred, not checked on
    // it. Leave out the (large) and (extra large) sizes:
    // they share these colours. tests/tst_appearances.qml compares every
    // value here with that JSON (tests/data/system-colour-schemes.json).
    readonly property var systemColours: ({
        "brick": { ActiveBorder: "#c2bfa5", ActiveCaption: "#800000", ActiveCaptionText: "#e1e0d2", AppWorkspace: "#e1e0d2", Control: "#c2bfa5", ControlDark: "#8d8961", ControlDarkDark: "#000000", ControlLight: "#c2bfa5", ControlLightLight: "#e1e0d2", ControlText: "#000000", Desktop: "#420000", GradientActiveCaption: "#b07440", GradientInactiveCaption: "#c8b870", GrayText: "#8d8961", Highlight: "#8d8961", HighlightText: "#ffffff", HotTrack: "#800000", InactiveBorder: "#c2bfa5", InactiveCaption: "#8d8961", InactiveCaptionText: "#e1e0d2", Info: "#e1e0d2", InfoText: "#800000", Menu: "#c2bfa5", MenuBar: "#c2bfa5", MenuHighlight: "#8d8961", MenuText: "#000000", ScrollBar: "#e1e0d2", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "desert": { ActiveBorder: "#d5ccbb", ActiveCaption: "#008080", ActiveCaptionText: "#ffffff", AppWorkspace: "#a28d68", Control: "#d5ccbb", ControlDark: "#a28d68", ControlDarkDark: "#000000", ControlLight: "#d5ccbb", ControlLightLight: "#eae6dd", ControlText: "#000000", Desktop: "#a28d68", GradientActiveCaption: "#84bdaa", GradientInactiveCaption: "#e8d080", GrayText: "#a28d68", Highlight: "#008080", HighlightText: "#ffffff", HotTrack: "#008080", InactiveBorder: "#d5ccbb", InactiveCaption: "#a28d68", InactiveCaptionText: "#ffffff", Info: "#ffffff", InfoText: "#000000", Menu: "#d5ccbb", MenuBar: "#d5ccbb", MenuHighlight: "#008080", MenuText: "#000000", ScrollBar: "#eae6dd", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "eggplant": { ActiveBorder: "#90b0a8", ActiveCaption: "#588078", ActiveCaptionText: "#ffffff", AppWorkspace: "#808080", Control: "#90b0a8", ControlDark: "#588078", ControlDarkDark: "#000000", ControlLight: "#90b0a8", ControlLightLight: "#c8d8d8", ControlText: "#000000", Desktop: "#400040", GradientActiveCaption: "#834b83", GradientInactiveCaption: "#cbbdd2", GrayText: "#588078", Highlight: "#588078", HighlightText: "#ffffff", HotTrack: "#588078", InactiveBorder: "#90b0a8", InactiveCaption: "#90b0a8", InactiveCaptionText: "#588078", Info: "#ffffff", InfoText: "#800080", Menu: "#90b0a8", MenuBar: "#90b0a8", MenuHighlight: "#588078", MenuText: "#000000", ScrollBar: "#90b0a8", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "lilac": { ActiveBorder: "#aea8d9", ActiveCaption: "#5a4eb1", ActiveCaptionText: "#ffffff", AppWorkspace: "#5a4eb1", Control: "#aea8d9", ControlDark: "#5a4eb1", ControlDarkDark: "#000000", ControlLight: "#aea8d9", ControlLightLight: "#d8d5ec", ControlText: "#000000", Desktop: "#000000", GradientActiveCaption: "#b68fcb", GradientInactiveCaption: "#b8b4d0", GrayText: "#5a4eb1", Highlight: "#5a4eb1", HighlightText: "#ffffff", HotTrack: "#5a4eb1", InactiveBorder: "#aea8d9", InactiveCaption: "#808080", InactiveCaptionText: "#ffffff", Info: "#ffffff", InfoText: "#000000", Menu: "#aea8d9", MenuBar: "#aea8d9", MenuHighlight: "#5a4eb1", MenuText: "#000000", ScrollBar: "#aea8d9", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "maple": { ActiveBorder: "#e6d8ae", ActiveCaption: "#800000", ActiveCaptionText: "#ffffff", AppWorkspace: "#c6a646", Control: "#e6d8ae", ControlDark: "#c6a646", ControlDarkDark: "#000000", ControlLight: "#e6d8ae", ControlLightLight: "#f2ecd7", ControlText: "#000000", Desktop: "#000000", GradientActiveCaption: "#c09c38", GradientInactiveCaption: "#e0c888", GrayText: "#c6a646", Highlight: "#c6a646", HighlightText: "#000000", HotTrack: "#c6a646", InactiveBorder: "#e6d8ae", InactiveCaption: "#c6a646", InactiveCaptionText: "#f2ecd7", Info: "#ffffff", InfoText: "#000000", Menu: "#e6d8ae", MenuBar: "#e6d8ae", MenuHighlight: "#c6a646", MenuText: "#000000", ScrollBar: "#f2ecd7", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "marine": { ActiveBorder: "#88c0b8", ActiveCaption: "#000080", ActiveCaptionText: "#ffffff", AppWorkspace: "#4b8d84", Control: "#88c0b8", ControlDark: "#489088", ControlDarkDark: "#000000", ControlLight: "#88c0b8", ControlLightLight: "#c8e0d8", ControlText: "#000000", Desktop: "#2c4e47", GradientActiveCaption: "#18b4c0", GradientInactiveCaption: "#78ccd8", GrayText: "#489088", Highlight: "#000080", HighlightText: "#ffffff", HotTrack: "#000080", InactiveBorder: "#88c0b8", InactiveCaption: "#489088", InactiveCaptionText: "#c0c0c0", Info: "#c8e0d8", InfoText: "#000000", Menu: "#88c0b8", MenuBar: "#88c0b8", MenuHighlight: "#000080", MenuText: "#000000", ScrollBar: "#c8e0d8", Window: "#c8e0d8", WindowFrame: "#000000", WindowText: "#000000" },
        "plum": { ActiveBorder: "#a89890", ActiveCaption: "#484060", ActiveCaptionText: "#ffffff", AppWorkspace: "#74635a", Control: "#a89890", ControlDark: "#786058", ControlDarkDark: "#000000", ControlLight: "#a89890", ControlLightLight: "#d8d0c8", ControlText: "#000000", Desktop: "#402840", GradientActiveCaption: "#a084b8", GradientInactiveCaption: "#a89878", GrayText: "#786058", Highlight: "#008080", HighlightText: "#d8d0c8", HotTrack: "#484060", InactiveBorder: "#a89890", InactiveCaption: "#786058", InactiveCaptionText: "#a89890", Info: "#d5ccc8", InfoText: "#300058", Menu: "#a89890", MenuBar: "#a89890", MenuHighlight: "#008080", MenuText: "#000000", ScrollBar: "#d8d0c8", Window: "#d8d0c8", WindowFrame: "#000000", WindowText: "#000000" },
        "pumpkin": { ActiveBorder: "#ecd59d", ActiveCaption: "#d7a52f", ActiveCaptionText: "#ffffff", AppWorkspace: "#f5eacf", Control: "#ecd59d", ControlDark: "#d7a52f", ControlDarkDark: "#000000", ControlLight: "#ecd59d", ControlLightLight: "#f5eacf", ControlText: "#000000", Desktop: "#420042", GradientActiveCaption: "#e0cc88", GradientInactiveCaption: "#d0cc90", GrayText: "#d7a52f", Highlight: "#800080", HighlightText: "#ffffff", HotTrack: "#d7a52f", InactiveBorder: "#ecd59d", InactiveCaption: "#a0a0a4", InactiveCaptionText: "#f5eacf", Info: "#ffffff", InfoText: "#800080", Menu: "#ecd59d", MenuBar: "#ecd59d", MenuHighlight: "#800080", MenuText: "#000000", ScrollBar: "#f5eacf", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "rainy-day": { ActiveBorder: "#8399b1", ActiveCaption: "#4f657d", ActiveCaptionText: "#ffffff", AppWorkspace: "#808080", Control: "#8399b1", ControlDark: "#4f657d", ControlDarkDark: "#000000", ControlLight: "#8399b1", ControlLightLight: "#c1ccd9", ControlText: "#000000", Desktop: "#000000", GradientActiveCaption: "#80b4d0", GradientInactiveCaption: "#b0bcd0", GrayText: "#4f657d", Highlight: "#4f657d", HighlightText: "#ffffff", HotTrack: "#4f657d", InactiveBorder: "#8399b1", InactiveCaption: "#808080", InactiveCaptionText: "#c1ccd9", Info: "#ffffff", InfoText: "#000000", Menu: "#8399b1", MenuBar: "#8399b1", MenuHighlight: "#4f657d", MenuText: "#000000", ScrollBar: "#c1ccd9", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "red-white-blue": { ActiveBorder: "#c0c0c0", ActiveCaption: "#800000", ActiveCaptionText: "#ffffff", AppWorkspace: "#ffffff", Control: "#c0c0c0", ControlDark: "#808080", ControlDarkDark: "#000000", ControlLight: "#c0c0c0", ControlLightLight: "#ffffff", ControlText: "#000000", Desktop: "#000042", GradientActiveCaption: "#0010a8", GradientInactiveCaption: "#babec9", GrayText: "#808080", Highlight: "#800000", HighlightText: "#ffffff", HotTrack: "#800000", InactiveBorder: "#c0c0c0", InactiveCaption: "#808080", InactiveCaptionText: "#c0c0c0", Info: "#ffffff", InfoText: "#000080", Menu: "#c0c0c0", MenuBar: "#c0c0c0", MenuHighlight: "#800000", MenuText: "#000000", ScrollBar: "#c0c0c0", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "rose": { ActiveBorder: "#cfafb7", ActiveCaption: "#9f6070", ActiveCaptionText: "#ffffff", AppWorkspace: "#9f6070", Control: "#cfafb7", ControlDark: "#9f6070", ControlDarkDark: "#000000", ControlLight: "#cfafb7", ControlLightLight: "#e7d8dc", ControlText: "#000000", Desktop: "#808080", GradientActiveCaption: "#d8ccd0", GradientInactiveCaption: "#d0d4d0", GrayText: "#9f6070", Highlight: "#9f6070", HighlightText: "#ffffff", HotTrack: "#9f6070", InactiveBorder: "#cfafb7", InactiveCaption: "#a0a0a4", InactiveCaptionText: "#7d7d7d", Info: "#ffffff", InfoText: "#000000", Menu: "#cfafb7", MenuBar: "#cfafb7", MenuHighlight: "#9f6070", MenuText: "#000000", ScrollBar: "#cfafb7", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "slate": { ActiveBorder: "#9db9c8", ActiveCaption: "#558097", ActiveCaptionText: "#ffffff", AppWorkspace: "#424242", Control: "#9db9c8", ControlDark: "#558097", ControlDarkDark: "#000000", ControlLight: "#9db9c8", ControlLightLight: "#cedce3", ControlText: "#000000", Desktop: "#414141", GradientActiveCaption: "#88b8d8", GradientInactiveCaption: "#a0bcc8", GrayText: "#558097", Highlight: "#558097", HighlightText: "#ffffff", HotTrack: "#558097", InactiveBorder: "#9db9c8", InactiveCaption: "#808080", InactiveCaptionText: "#c0c0c0", Info: "#ffffff", InfoText: "#000000", Menu: "#9db9c8", MenuBar: "#9db9c8", MenuHighlight: "#558097", MenuText: "#000000", ScrollBar: "#cedce3", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "spruce": { ActiveBorder: "#a2c8a9", ActiveCaption: "#599764", ActiveCaptionText: "#ffffff", AppWorkspace: "#d0e3d3", Control: "#a2c8a9", ControlDark: "#599764", ControlDarkDark: "#000000", ControlLight: "#a2c8a9", ControlLightLight: "#d0e3d3", ControlText: "#000000", Desktop: "#213f21", GradientActiveCaption: "#98c8e8", GradientInactiveCaption: "#a8ccb0", GrayText: "#599764", Highlight: "#599764", HighlightText: "#ffffff", HotTrack: "#599764", InactiveBorder: "#a2c8a9", InactiveCaption: "#808080", InactiveCaptionText: "#d0e3d3", Info: "#ffffff", InfoText: "#000000", Menu: "#a2c8a9", MenuBar: "#a2c8a9", MenuHighlight: "#599764", MenuText: "#000000", ScrollBar: "#d0e3d3", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "storm": { ActiveBorder: "#c0c0c0", ActiveCaption: "#800080", ActiveCaptionText: "#ffffff", AppWorkspace: "#808080", Control: "#c0c0c0", ControlDark: "#808080", ControlDarkDark: "#000000", ControlLight: "#c0c0c0", ControlLightLight: "#ffffff", ControlText: "#000000", Desktop: "#000000", GradientActiveCaption: "#388cb0", GradientInactiveCaption: "#a8aca8", GrayText: "#808080", Highlight: "#800080", HighlightText: "#ffffff", HotTrack: "#800080", InactiveBorder: "#c0c0c0", InactiveCaption: "#808080", InactiveCaptionText: "#c0c0c0", Info: "#ffffff", InfoText: "#800080", Menu: "#c0c0c0", MenuBar: "#c0c0c0", MenuHighlight: "#800080", MenuText: "#000000", ScrollBar: "#c0c0c0", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "teal": { ActiveBorder: "#c0c0c0", ActiveCaption: "#008080", ActiveCaptionText: "#ffffff", AppWorkspace: "#808080", Control: "#c0c0c0", ControlDark: "#808080", ControlDarkDark: "#000000", ControlLight: "#c0c0c0", ControlLightLight: "#ffffff", ControlText: "#000000", Desktop: "#004040", GradientActiveCaption: "#00ccd8", GradientInactiveCaption: "#98c8b8", GrayText: "#808080", Highlight: "#008080", HighlightText: "#ffffff", HotTrack: "#008080", InactiveBorder: "#c0c0c0", InactiveCaption: "#808080", InactiveCaptionText: "#fffbf0", Info: "#ffffff", InfoText: "#000000", Menu: "#c0c0c0", MenuBar: "#c0c0c0", MenuHighlight: "#008080", MenuText: "#000000", ScrollBar: "#c0c0c0", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "wheat": { ActiveBorder: "#dedea0", ActiveCaption: "#808000", ActiveCaptionText: "#ffffff", AppWorkspace: "#bcbc41", Control: "#dedea0", ControlDark: "#bcbc41", ControlDarkDark: "#000000", ControlLight: "#dedea0", ControlLightLight: "#eeeed0", ControlText: "#000000", Desktop: "#00401d", GradientActiveCaption: "#c8b048", GradientInactiveCaption: "#b8b880", GrayText: "#bcbc41", Highlight: "#808000", HighlightText: "#ffffff", HotTrack: "#808000", InactiveBorder: "#dedea0", InactiveCaption: "#bcbc41", InactiveCaptionText: "#ffffff", Info: "#ffffff", InfoText: "#000000", Menu: "#dedea0", MenuBar: "#dedea0", MenuHighlight: "#808000", MenuText: "#000000", ScrollBar: "#eeeed0", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "high-contrast-black": { ActiveBorder: "#ffff00", ActiveCaption: "#800080", ActiveCaptionText: "#ffffff", AppWorkspace: "#000000", Control: "#000000", ControlDark: "#808080", ControlDarkDark: "#ffffff", ControlLight: "#ffffff", ControlLightLight: "#c0c0c0", ControlText: "#ffffff", Desktop: "#000000", GradientActiveCaption: "#800080", GradientInactiveCaption: "#008000", GrayText: "#00ff00", Highlight: "#800080", HighlightText: "#ffffff", HotTrack: "#800080", InactiveBorder: "#008000", InactiveCaption: "#008000", InactiveCaptionText: "#ffffff", Info: "#000000", InfoText: "#ffffff", Menu: "#000000", MenuBar: "#000000", MenuHighlight: "#800080", MenuText: "#ffffff", ScrollBar: "#000000", Window: "#000000", WindowFrame: "#ffffff", WindowText: "#ffffff" },
        "high-contrast-white": { ActiveBorder: "#808080", ActiveCaption: "#000000", ActiveCaptionText: "#ffffff", AppWorkspace: "#808080", Control: "#ffffff", ControlDark: "#808080", ControlDarkDark: "#000000", ControlLight: "#c0c0c0", ControlLightLight: "#c0c0c0", ControlText: "#000000", Desktop: "#ffffff", GradientActiveCaption: "#000000", GradientInactiveCaption: "#ffffff", GrayText: "#00ff00", Highlight: "#000000", HighlightText: "#ffffff", HotTrack: "#000000", InactiveBorder: "#c0c0c0", InactiveCaption: "#ffffff", InactiveCaptionText: "#000000", Info: "#ffffff", InfoText: "#000000", Menu: "#ffffff", MenuBar: "#ffffff", MenuHighlight: "#000000", MenuText: "#000000", ScrollBar: "#ffffff", Window: "#ffffff", WindowFrame: "#000000", WindowText: "#000000" },
        "high-contrast-1": { ActiveBorder: "#0000ff", ActiveCaption: "#0000ff", ActiveCaptionText: "#ffffff", AppWorkspace: "#000000", Control: "#000000", ControlDark: "#808080", ControlDarkDark: "#ffffff", ControlLight: "#ffffff", ControlLightLight: "#c0c0c0", ControlText: "#ffffff", Desktop: "#000000", GradientActiveCaption: "#0000ff", GradientInactiveCaption: "#00ffff", GrayText: "#00ff00", Highlight: "#008000", HighlightText: "#ffffff", HotTrack: "#800080", InactiveBorder: "#00ffff", InactiveCaption: "#00ffff", InactiveCaptionText: "#000000", Info: "#000000", InfoText: "#ffff00", Menu: "#000000", MenuBar: "#000000", MenuHighlight: "#008000", MenuText: "#ffffff", ScrollBar: "#000000", Window: "#000000", WindowFrame: "#ffffff", WindowText: "#ffff00" },
        "high-contrast-2": { ActiveBorder: "#00ffff", ActiveCaption: "#00ffff", ActiveCaptionText: "#000000", AppWorkspace: "#ffffff", Control: "#000000", ControlDark: "#808080", ControlDarkDark: "#ffffff", ControlLight: "#ffffff", ControlLightLight: "#c0c0c0", ControlText: "#00ff00", Desktop: "#000000", GradientActiveCaption: "#00ffff", GradientInactiveCaption: "#0000ff", GrayText: "#00ff00", Highlight: "#0000ff", HighlightText: "#ffffff", HotTrack: "#800080", InactiveBorder: "#0000ff", InactiveCaption: "#0000ff", InactiveCaptionText: "#ffffff", Info: "#ffff00", InfoText: "#000000", Menu: "#000000", MenuBar: "#000000", MenuHighlight: "#0000ff", MenuText: "#00ff00", ScrollBar: "#000000", Window: "#000000", WindowFrame: "#ffffff", WindowText: "#00ff00" }
    })

    // ---- colours. hi/li: outer/inner light edge; sh/dk: inner/outer dark edge.
    // palette(id) is the one source: the properties below read the current
    // appearance, and a preview of another scheme (Display Properties)
    // passes palette("brick") to the controls that draw it. palette(true)
    // and palette(false) still mean Dark grey and Standard.
    function palette(which) {
        if (typeof which !== "string") return root.basePalette(!!which);
        const info = root.appearanceInfo(which);
        if (!info) return root.basePalette(Theme.dark);
        const sys = root.systemColours[which];
        return sys ? root.schemePalette(sys, info.dark) : root.basePalette(info.dark);
    }

    // A scheme: every token with a system colour takes it (the
    // contract's map). The tokens it has none for (status colours, charts,
    // the icon outline) take Standard's in a light scheme and Dark grey's in
    // a dark one, with Dark grey's precedents: no emboss under grey text on
    // a dark face, and grey icon outlines where black would vanish.
    // Progress blocks (meter) are the Highlight, as the original drew them.
    function schemePalette(c, dark) {
        const p = root.basePalette(dark);
        p.face = c.Control;
        p.hi = c.ControlLightLight;
        p.li = c.ControlLight;
        p.sh = c.ControlDark;
        p.dk = c.ControlDarkDark;
        p.text = c.ControlText;
        p.gray = c.GrayText;
        p.emboss = dark ? "transparent" : c.ControlLightLight;
        p.win = c.Window;
        p.winText = c.WindowText;
        p.selection = c.Highlight;
        p.selectionText = c.HighlightText;
        p.caption1 = c.ActiveCaption;
        p.caption2 = c.GradientActiveCaption;
        p.captionText = c.ActiveCaptionText;
        p.inactiveCaption1 = c.InactiveCaption;
        p.inactiveCaption2 = c.GradientInactiveCaption;
        p.inactiveCaptionText = c.InactiveCaptionText;
        p.tip = c.Info;
        p.tipText = c.InfoText;
        p.tipEdge = c.WindowFrame;
        p.desktop = c.Desktop;
        p.dither = c.ControlLightLight;
        p.focus = c.ControlText;
        p.meter = c.Highlight;
        p.menu = c.Menu;
        p.menuText = c.MenuText;
        p.bandText = c.ActiveCaptionText;
        p.bandSubText = c.InactiveCaptionText;
        p.windowFrame = c.WindowFrame;
        p.scrollTrack = c.ScrollBar;
        // The scroll track: solid ScrollBar, except where the light edge is
        // the window's own colour; then the face and light-edge dither, so
        // the track still differs from the window (Wine's and ReactOS's
        // WM_CTLCOLORSCROLLBAR default; inferred, not checked on the original).
        p.scrollDither = c.ControlLightLight === c.Window;
        return p;
    }

    // Standard and Dark grey: Hensou's own, unchanged.
    // ink is the icons' outline: black on #C0C0C0, but on #3C3C3C black has
    // 1.9:1 and the outlines vanish, so dark grey draws them in a grey that
    // stays darker than the icons' white and yellow fills.
    function basePalette(dark) {
        return {
            face: dark ? "#3c3c3c" : "#c0c0c0",
            hi: dark ? "#7a7a7a" : "#ffffff",
            li: dark ? "#565656" : "#dfdfdf",
            sh: dark ? "#222222" : "#808080",
            dk: "#000000",
            text: dark ? "#ececec" : "#000000",
            gray: dark ? "#8e8e8e" : "#808080",
            emboss: dark ? "transparent" : "#ffffff",
            win: dark ? "#1d1d1d" : "#ffffff",
            winText: dark ? "#e8e8e8" : "#000000",
            // Dark grey's caption is steel, not navy: Simon found the navy
            // jarring in dark mode. The selection takes the same steel, as
            // Windows Standard's selection takes its caption's navy. White
            // has 12.2:1 on caption1 and 5.1:1 on caption2 (WCAG AA at both
            // ends) and 6.4:1 on the selection. Light stays Windows Standard.
            // docs/plans/desktop-themes.md, "Memphis dark caption".
            selection: dark ? "#41608a" : "#000080",
            selectionText: "#ffffff",
            caption1: dark ? "#26364f" : "#000080",
            caption2: dark ? "#56708e" : "#1084d0",
            inactiveCaption1: dark ? "#2a2a2a" : "#808080",
            inactiveCaption2: dark ? "#4a4a4a" : "#c0c0c0",
            captionText: "#ffffff",
            inactiveCaptionText: dark ? "#9a9a9a" : "#c0c0c0",
            tip: dark ? "#3a3a2a" : "#ffffe1",
            tipText: dark ? "#f0f0d8" : "#000000",
            tipEdge: dark ? "#8a8a7a" : "#000000",
            desktop: dark ? "#000000" : "#008080",
            dither: dark ? "#565656" : "#ffffff",
            danger: dark ? "#ff8a80" : "#800000",
            warning: dark ? "#e0b060" : "#5c4400",
            ok: dark ? "#7fd07f" : "#008000",
            badge: dark ? "#d03030" : "#c00000",
            focus: dark ? "#ececec" : "#000000",
            ink: dark ? "#9a9a9a" : "#000000",
            // The Fleet views (the approved mock pass 2, pass2.css): System
            // Monitor's lines and grid, Resource Meter's blocks, the drive pie.
            chartCpu: dark ? "#6ad46a" : "#008000",
            chartMem: dark ? "#7aa2ff" : "#0000ff",
            chartDisk: dark ? "#d080d0" : "#800080",
            chartNet: dark ? "#d0c060" : "#808000",
            chartGrid: dark ? "#3a3a3a" : "#c0c0c0",
            meter: dark ? "#5f7fff" : "#000080",
            meterWarn: dark ? "#e0b060" : "#808000",
            meterDanger: dark ? "#ff6060" : "#ff0000",
            meterStale: dark ? "#6a6a6a" : "#808080",
            pieUsed: dark ? "#4060ff" : "#0000ff",
            pieUsedSide: dark ? "#2030a0" : "#000080",
            pieFree: dark ? "#e040e0" : "#ff00ff",
            pieFreeSide: dark ? "#802080" : "#800080",
            // Tokens the schemes added. Standard and Dark grey keep the
            // colours these places drew before: menus on the face, the Start
            // band's white and grey words, a black window frame, the scroll
            // track dithered over the face.
            menu: dark ? "#3c3c3c" : "#c0c0c0",
            menuText: dark ? "#ececec" : "#000000",
            bandText: "#ffffff",
            bandSubText: "#c0c0c0",
            windowFrame: "#000000",
            scrollTrack: dark ? "#3c3c3c" : "#c0c0c0",
            scrollDither: true
        };
    }
    readonly property var current: palette(appearance)
    readonly property color face: current.face
    readonly property color hi: current.hi
    readonly property color li: current.li
    readonly property color sh: current.sh
    readonly property color dk: current.dk
    readonly property color text: current.text
    readonly property color gray: current.gray
    readonly property color emboss: current.emboss
    readonly property color win: current.win
    readonly property color winText: current.winText
    readonly property color selection: current.selection
    readonly property color selectionText: current.selectionText
    readonly property color caption1: current.caption1
    readonly property color caption2: current.caption2
    readonly property color inactiveCaption1: current.inactiveCaption1
    readonly property color inactiveCaption2: current.inactiveCaption2
    readonly property color captionText: current.captionText
    readonly property color inactiveCaptionText: current.inactiveCaptionText
    readonly property color tip: current.tip
    readonly property color tipText: current.tipText
    readonly property color tipEdge: current.tipEdge
    readonly property color desktop: current.desktop
    readonly property color dither: current.dither
    readonly property color danger: current.danger
    readonly property color warning: current.warning
    readonly property color ok: current.ok
    readonly property color badge: current.badge
    readonly property color focus: current.focus
    readonly property color ink: current.ink
    readonly property color chartCpu: current.chartCpu
    readonly property color chartMem: current.chartMem
    readonly property color chartDisk: current.chartDisk
    readonly property color chartNet: current.chartNet
    readonly property color chartGrid: current.chartGrid
    readonly property color meter: current.meter
    readonly property color meterWarn: current.meterWarn
    readonly property color meterDanger: current.meterDanger
    readonly property color meterStale: current.meterStale
    readonly property color pieUsed: current.pieUsed
    readonly property color pieUsedSide: current.pieUsedSide
    readonly property color pieFree: current.pieFree
    readonly property color pieFreeSide: current.pieFreeSide
    readonly property color menu: current.menu
    readonly property color menuText: current.menuText
    readonly property color bandText: current.bandText
    readonly property color bandSubText: current.bandSubText
    readonly property color windowFrame: current.windowFrame
    readonly property color scrollTrack: current.scrollTrack
    readonly property bool scrollDither: current.scrollDither
    // The names every appearance resolves (tests walk them).
    readonly property var tokenNames: Object.keys(palette("standard"))

    function tone(name) {
        if (name === "danger") return root.danger;
        if (name === "warning") return root.warning;
        if (name === "ok") return root.ok;
        if (name === "muted" || name === "off") return root.gray;
        return root.text;
    }

    // ---- the font. W95FA Grid: one font pixel is 1 u at 12.5 u. Qt rounds
    // font sizes to whole logical pixels, so MemphisText draws at 25 px (two
    // text pixels per font pixel, exact) and scales by u / 2.
    readonly property string fontFamily: "W95FA Grid"
    readonly property int fontRaster: 25
    readonly property real textScale: u / 2
    readonly property int lineUnits: 13       // ascent 10 + descent 3
    readonly property int ascentUnits: 10
    readonly property real line: lineUnits * u

    property FontMetrics fontMetrics: FontMetrics {
        id: metrics
        font.family: root.fontFamily
        font.pixelSize: root.fontRaster
        font.hintingPreference: Font.PreferNoHinting
        font.kerning: false
    }

    // A string's width in logical px. Drawn bold adds 1 u per letter.
    function textWidth(s, bold, unit) {
        const str = String(s), k = unit || root.u;
        return metrics.advanceWidth(str) * k / 2 + (bold ? str.length * k : 0);
    }
    function widest(strings, bold, unit) {
        let w = 0;
        for (const s of strings) w = Math.max(w, root.textWidth(s, bold, unit));
        return w;
    }

    // "&Programs" -> "Programs" with access index 0; "&&" is a literal &.
    function plainText(s) {
        return String(s).replace(/&(&?)/g, (m, lit) => lit ? "&" : "");
    }
    function accessIndex(s) {
        const str = String(s);
        let out = 0;
        for (let i = 0; i < str.length; i++) {
            if (str[i] === "&") {
                if (str[i + 1] === "&") { out++; i++; continue; }
                return i + 1 < str.length ? out : -1;
            }
            out++;
        }
        return -1;
    }
    // The key a letter press matches: the marked letter, or the first.
    function accessKey(s) {
        const plain = root.plainText(s);
        const i = root.accessIndex(s);
        return (i >= 0 ? plain.charAt(i) : plain.charAt(0)).toLowerCase();
    }

    // ---- metrics, in units (multiply by u). From the mock's CSS.
    readonly property int buttonHeight: 23
    readonly property int buttonSmallHeight: 21
    readonly property int buttonMinWidth: 75
    readonly property int fieldHeight: 21
    readonly property int captionHeight: 18
    readonly property int captionButtonWidth: 16
    readonly property int captionButtonHeight: 14
    readonly property int frame: 3                 // window and menu padding
    readonly property int menuItemHeight: 18
    readonly property int menuBigItemHeight: 32
    readonly property int menuBand: 26
    readonly property int scrollBar: 16
    readonly property int listRow: 16
    readonly property int listRowTwo: 34
    readonly property int tabStrip: 22
    readonly property int toolButton: 22
    readonly property int trayButton: 20
    readonly property int statusPane: 18
    readonly property int checkBox: 13
    readonly property int radio: 12
}
