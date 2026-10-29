pragma Singleton

import QtQuick
import "resources.js" as Resources

// The SVG icons of the top bar and its menus, read once from icons/.
//
// ChicagoFLF has no ● ○ ✓ × arrows or lock, and the bar draws no glyph
// from another face, so every mark is an SVG file. A file draws in
// `currentColor` and, where a mark cuts into another, in #ff00ff for the
// knock-out. url() swaps both for real colours and returns a data URL, so
// one file serves every tone, the open title and both appearances.
QtObject {
    id: root

    // The top bar's quiet glyphs carry a value in the icon: speaker-0..3
    // (lit waves; muted adds the slash), brightness-1..8 (lit rays) and
    // cloud-meter (the cloud with the worst profile's meter; the bar
    // draws the fill). Straight edges sit on whole device pixels at 1.5.
    // layout-tile-1..3 and layout-float are the Layout control's glyph;
    // layout-cap-1..3 are its capacity pictures, whose tiles take the
    // knock colour (the highlight on the chosen one).
    readonly property var sources: Resources.platinum
    readonly property var names: Object.keys(sources)

    function url(name, color, knock) {
        const svg = root.sources[name];
        if (!svg) return "";
        const filled = svg.replace(/currentColor/g, String(color))
            .replace(/#ff00ff/g, String(knock || "transparent"));
        return "data:image/svg+xml;utf8," + encodeURIComponent(filled);
    }
}
