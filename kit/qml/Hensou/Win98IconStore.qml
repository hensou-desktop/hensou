pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import "resources.js" as Resources

// The Win98 icon set, read once from themes/win98/icons/. The files are
// the approved mock's icons (dev/make-icons.sh), in the 16-colour palette
// on a 16-u grid (24 u for the Start menu's large icons).
//
// Placeholders that url() swaps for real colours:
//   #000001       outline (Win98Tokens.ink)
//   currentColor  the surface's text colour
//   #00ff01       battery level colour; width="7.77" its length (0 to 8 u)
QtObject {
    id: root

    readonly property var sources: Resources.win98
    readonly property var names: Object.keys(sources)

    function has(name) { return root.sources[name] !== undefined; }

    // The intrinsic size of an icon, in units: [width, height].
    function size(name) {
        const svg = root.sources[name];
        if (!svg) return [16, 16];
        const w = /width="([0-9.]+)"/.exec(svg), h = /height="([0-9.]+)"/.exec(svg);
        return [w ? Number(w[1]) : 16, h ? Number(h[1]) : 16];
    }

    // level: 0..1 for the battery; tone: its colour.
    function url(name, color, level, tone) {
        const svg = root.sources[name];
        if (!svg) return "";
        let out = svg.replace(/#000001/g, String(Win98Tokens.ink))
            .replace(/currentColor/g, String(color));
        if (level !== undefined && level !== null) {
            const w = Math.max(0, Math.min(8, Math.round(8 * level)));
            out = out.replace('width="7.77"', 'width="' + w + '"')
                .replace(/#00ff01/g, String(tone || "#00a000"));
        }
        return "data:image/svg+xml;utf8," + encodeURIComponent(out);
    }
}
