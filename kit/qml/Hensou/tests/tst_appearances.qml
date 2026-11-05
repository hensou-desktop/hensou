import QtQuick
import QtTest
import Hensou

// Every appearance resolves every token, the 20 Memphis schemes equal
// their source JSON, and Standard, Dark grey and Platinum's existing
// appearances keep the values they had before appearances existed
// (data/baseline-1e4c5e6.json). Needs QML_XHR_ALLOW_FILE_READ=1 (run.sh).
TestCase {
    id: test
    name: "HensouAppearances"
    width: 400
    height: 300
    when: windowShown
    visible: true

    readonly property bool hasAppearance: typeof Theme.appearance === "string"

    function readJson(file) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("data/" + file), false);
        xhr.send();
        verify(xhr.responseText.length > 0, file + " is readable");
        return JSON.parse(xhr.responseText);
    }
    function schemesByName() {
        const out = {};
        for (const s of readJson("system-colour-schemes.json")) out[s.name] = s.colors;
        return out;
    }
    function same(a, b) { return Qt.colorEqual(a, b); }

    // id -> the scheme's name in the source JSON.
    readonly property var sourceNames: ({
        "brick": "Brick", "desert": "Desert", "eggplant": "Eggplant", "lilac": "Lilac",
        "maple": "Maple", "marine": "Marine", "plum": "Plum", "pumpkin": "Pumpkin",
        "rainy-day": "Rainy Day", "red-white-blue": "Red White Blue", "rose": "Rose",
        "slate": "Slate", "spruce": "Spruce", "storm": "Storm", "teal": "Teal", "wheat": "Wheat",
        "high-contrast-black": "High Contrast Black", "high-contrast-white": "High Contrast White",
        "high-contrast-1": "High Contrast #1", "high-contrast-2": "High Contrast #2"
    })
    // The contract's map from tokens to system colour names.
    readonly property var systemMap: ({
        face: "Control", hi: "ControlLightLight", li: "ControlLight", sh: "ControlDark",
        dk: "ControlDarkDark", text: "ControlText", gray: "GrayText", win: "Window",
        winText: "WindowText", selection: "Highlight", selectionText: "HighlightText",
        caption1: "ActiveCaption", caption2: "GradientActiveCaption", captionText: "ActiveCaptionText",
        inactiveCaption1: "InactiveCaption", inactiveCaption2: "GradientInactiveCaption",
        inactiveCaptionText: "InactiveCaptionText", desktop: "Desktop", tip: "Info",
        tipText: "InfoText", menu: "Menu", menuText: "MenuText"
    })

    function init() {
        Theme.name = "memphis"; Theme.mode = "light"; Theme.extraState = "off";
        if (hasAppearance) Theme.appearance = "";
    }
    function cleanupTestCase() { init(); }

    function test_memphis_ids_labels_and_modes() {
        const ids = MemphisTokens.appearances.map(a => a.id);
        compare(ids, ["standard", "dark-grey", "brick", "desert", "eggplant", "lilac", "maple", "marine",
            "plum", "pumpkin", "rainy-day", "red-white-blue", "rose", "slate", "spruce", "storm", "teal",
            "wheat", "high-contrast-black", "high-contrast-white", "high-contrast-1", "high-contrast-2"]);
        compare(MemphisTokens.appearances.map(a => a.label), ["Standard", "Dark grey", "Brick", "Desert",
            "Eggplant", "Lilac", "Maple", "Marine", "Plum", "Pumpkin", "Rainy Day", "Red, White and Blue",
            "Rose", "Slate", "Spruce", "Storm", "Teal", "Wheat", "High Contrast Black",
            "High Contrast White", "High Contrast #1", "High Contrast #2"]);
        compare(MemphisTokens.appearances.filter(a => a.dark).map(a => a.id),
            ["dark-grey", "high-contrast-black", "high-contrast-1", "high-contrast-2"]);
        for (const a of MemphisTokens.appearances) verify(!/windows/i.test(a.label), a.label);
        compare(PlatinumTokens.appearances.map(a => a.id), ["light", "dark-grey", "drawing-board"]);
        compare(PlatinumTokens.appearances.map(a => a.label), ["Light", "Dark grey", "Drawing Board"]);
        compare(PlatinumTokens.appearances.filter(a => a.dark).map(a => a.id), ["dark-grey"]);
    }

    function test_every_memphis_appearance_resolves_every_token() {
        const names = MemphisTokens.tokenNames;
        verify(names.length >= 45, "token count " + names.length);
        for (const a of MemphisTokens.appearances) {
            const p = MemphisTokens.palette(a.id);
            compare(Object.keys(p).sort(), names.slice().sort(), a.id + " has every token and no other");
            for (const k of names) {
                const v = p[k];
                verify(v !== undefined && v !== null && v !== "", a.id + "." + k + " is defined");
                if (k === "scrollDither") compare(typeof v, "boolean", a.id + ".scrollDither");
                else verify(/^(#[0-9a-f]{6}|#[0-9a-f]{8}|transparent)$/.test(v), a.id + "." + k + " = " + v);
            }
        }
    }

    function test_schemes_equal_the_source_json() {
        const src = schemesByName();
        compare(Object.keys(MemphisTokens.systemColours).length, 20);
        for (const id in sourceNames) {
            const c = src[sourceNames[id]];
            verify(c !== undefined, sourceNames[id] + " is in the JSON");
            // The embedded table is the JSON, all 30 colours, verbatim.
            compare(JSON.stringify(MemphisTokens.systemColours[id]), JSON.stringify(Object.keys(c).sort()
                .reduce((o, k) => { o[k] = c[k]; return o; }, {})), id + " table equals the JSON");
            const p = MemphisTokens.palette(id);
            for (const token in systemMap)
                compare(p[token], c[systemMap[token]], id + "." + token + " = " + systemMap[token]);
            const dark = MemphisTokens.appearanceInfo(id).dark;
            compare(p.emboss, dark ? "transparent" : c.ControlLightLight, id + ".emboss");
            compare(p.dither, c.ControlLightLight, id + ".dither");
            compare(p.meter, c.Highlight, id + ".meter");
            compare(p.tipEdge, c.WindowFrame, id + ".tipEdge");
            compare(p.scrollTrack, c.ScrollBar, id + ".scrollTrack");
            compare(p.scrollDither, c.ControlLightLight === c.Window, id + ".scrollDither");
            // Tokens without a system colour: Standard's or Dark grey's.
            const base = MemphisTokens.palette(dark ? "dark-grey" : "standard");
            for (const k of ["danger", "warning", "ok", "badge", "ink", "chartCpu", "pieFree"])
                compare(p[k], base[k], id + "." + k + " follows " + (dark ? "Dark grey" : "Standard"));
        }
    }

    function test_standard_and_dark_grey_are_unchanged() {
        const before = readJson("baseline-1e4c5e6.json").memphis;
        for (const id of ["standard", "dark-grey"]) {
            const now = MemphisTokens.palette(id);
            for (const k in before[id]) compare(now[k], before[id][k], id + "." + k + " unchanged");
            // The old boolean call still means the same thing.
            compare(JSON.stringify(MemphisTokens.palette(id === "dark-grey")), JSON.stringify(now));
        }
        // Dark keeps OLED black.
        compare(MemphisTokens.palette("dark-grey").desktop, "#000000");
        for (const id of ["high-contrast-black", "high-contrast-1", "high-contrast-2"])
            compare(MemphisTokens.palette(id).desktop, "#000000", id + " desktop stays black");
    }

    function test_resolve_falls_back_from_mode() {
        compare(MemphisTokens.resolve("", false), "standard");
        compare(MemphisTokens.resolve("", true), "dark-grey");
        compare(MemphisTokens.resolve(undefined, true), "dark-grey");
        compare(MemphisTokens.resolve("not-a-scheme", false), "standard");
        compare(MemphisTokens.resolve("not-a-scheme", true), "dark-grey");
        compare(MemphisTokens.resolve("drawing-board", false), "standard", "another theme's ID is unknown here");
        compare(MemphisTokens.resolve("brick", true), "brick");
        compare(PlatinumTokens.resolve("", false), "light");
        compare(PlatinumTokens.resolve("", true), "dark-grey");
        compare(PlatinumTokens.resolve("brick", true), "dark-grey");
        compare(PlatinumTokens.resolve("drawing-board", false), "drawing-board");
        // An unknown ID passed to palette() is the mode's default too.
        Theme.mode = "dark";
        compare(JSON.stringify(MemphisTokens.palette("nope")), JSON.stringify(MemphisTokens.palette("dark-grey")));
        Theme.mode = "light";
        compare(JSON.stringify(MemphisTokens.palette("nope")), JSON.stringify(MemphisTokens.palette("standard")));
    }

    function test_live_tokens_follow_mode_without_an_appearance() {
        Theme.mode = "light";
        compare(MemphisTokens.appearance, "standard");
        verify(same(MemphisTokens.face, "#c0c0c0"));
        compare(PlatinumTokens.appearance, "light");
        Theme.mode = "dark";
        compare(MemphisTokens.appearance, "dark-grey");
        verify(same(MemphisTokens.face, "#3c3c3c"));
        compare(PlatinumTokens.appearance, "dark-grey");
        verify(!PlatinumTokens.drafting);
    }

    function test_live_tokens_follow_theme_appearance() {
        if (!hasAppearance) skip("Theme.appearance is not on this branch yet (the build worker adds it)");
        const src = schemesByName();
        for (const id in sourceNames) {
            Theme.mode = MemphisTokens.appearanceInfo(id).dark ? "dark" : "light";
            Theme.appearance = id;
            compare(MemphisTokens.appearance, id);
            for (const token in systemMap)
                verify(same(MemphisTokens[token], src[sourceNames[id]][systemMap[token]]), id + " live " + token);
        }
        Theme.appearance = "unknown-scheme";
        Theme.mode = "dark";
        compare(MemphisTokens.appearance, "dark-grey");
        Theme.appearance = "drawing-board";
        Theme.mode = "light";
        compare(PlatinumTokens.appearance, "drawing-board");
        verify(PlatinumTokens.drafting);
        verify(same(PlatinumTokens.menuSurface, "#f4efe5"));
    }

    function test_every_platinum_appearance_resolves_every_token() {
        const names = PlatinumTokens.tokenNames;
        verify(names.length >= 40, "token count " + names.length);
        for (const a of PlatinumTokens.appearances) {
            for (const extra of [false, true]) {
                const p = PlatinumTokens.palette(a.id, extra);
                compare(Object.keys(p).sort(), names.slice().sort(), a.id + " has every token");
                for (const k of names)
                    verify(/^(#[0-9a-f]{6}|#[0-9a-f]{8}|transparent)$/.test(p[k]), a.id + "." + k + " = " + p[k]);
            }
        }
        // Extra dark changes nothing for the light appearances.
        for (const id of ["light", "drawing-board"])
            compare(JSON.stringify(PlatinumTokens.palette(id, true)), JSON.stringify(PlatinumTokens.palette(id, false)));
        // Drawing Board differs from Light in its paper, lines and ink.
        const board = PlatinumTokens.palette("drawing-board", false), light = PlatinumTokens.palette("light", false);
        for (const k of ["barSurface", "menuSurface", "menuEdge", "menuText", "highlight", "frameLine", "field"])
            verify(board[k] !== light[k], "drawing-board." + k + " is its own");
        compare(light.frameLine, "transparent");
    }

    function test_platinum_existing_appearances_are_unchanged() {
        const before = readJson("baseline-1e4c5e6.json").platinum;
        const cases = [["light", "light", "off"], ["dark-grey", "dark", "off"], ["dark-grey-extra", "dark", "on"]];
        for (const [key, mode, extra] of cases) {
            Theme.mode = mode; Theme.extraState = extra;
            verify(!PlatinumTokens.drafting);
            for (const k in before[key])
                verify(same(PlatinumTokens[k], before[key][k]), key + "." + k + ": " + PlatinumTokens[k] + " was " + before[key][k]);
        }
    }

    // ---- Drawing Board's drawing parts.
    WindowScale {
        id: scale
        width: 400; height: 300
        devicePixelRatio: 1.5
        Item {
            id: sheet
            x: 40; y: 40; width: 120; height: 80
            PlatinumCropMarks { id: marks; overrun: 7; color: "#3b3833" }
            PlatinumHatch { id: hatch; x: 140; width: 60; height: 40; color: "#8c8578" }
        }
    }
    function test_crop_marks_run_past_every_corner() {
        const hair = PlatinumTokens.hairFor(1.5);
        compare(marks.hair, hair);
        // Whole hairs: 7 px is 5 hairs (6.67 px) at 1.5.
        compare(marks.run, 5 * hair);
        const lines = marks.children;
        compare(lines.length, 4);
        compare(lines[0].x, -marks.run);
        compare(lines[0].width, sheet.width + 2 * marks.run);
        compare(lines[2].y, -marks.run);
        compare(lines[3].height, sheet.height + 2 * marks.run);
        for (const l of lines) verify(Math.min(l.width, l.height) === hair, "a hair wide");
    }
    function test_hatch_draws_at_physical_pixels() {
        compare(hatch.px, 2);
        compare(hatch.cols, Math.round(60 / hatch.hair));
        compare(hatch.sourceSize.width, hatch.cols * 2);
        tryCompare(hatch, "status", Image.Ready);
        verify(hatch.svg.indexOf('pattern id="h" width="3"') > 0);
        scale.devicePixelRatio = 1;
        compare(hatch.px, 1);
        compare(hatch.sourceSize.width, 60);
        scale.devicePixelRatio = 1.5;
    }
    function test_frames_hide_drafting_parts_outside_drawing_board() {
        Theme.name = "platinum"; Theme.mode = "light";
        const menu = Qt.createQmlObject('import QtQuick; import Hensou; PlatinumMenuFrame { title: "Sound"; width: 200 }', scale, "menu");
        const dialog = Qt.createQmlObject('import QtQuick; import Hensou; PlatinumDialogFrame { title: "About"; width: 200; height: 120 }', scale, "dialog");
        const hair = PlatinumTokens.hairFor(1.5);
        const parts = frame => {
            let shadow = null, marks = null;
            for (const k of frame.children) {
                if (k.toString().indexOf("PlatinumShadow") === 0) shadow = k;
                if (k.toString().indexOf("PlatinumCropMarks") === 0) marks = k;
            }
            verify(shadow !== null && marks !== null, "shadow and crop marks present");
            return { shadow: shadow, marks: marks };
        };
        // Light: the solid shadow where it was (menu 1 rule, dialog 2), no marks.
        for (const [frame, hairs] of [[menu, 1], [dialog, 2]]) {
            const p = parts(frame);
            verify(!p.shadow.hatched);
            compare(p.shadow.x, hairs * hair);
            verify(!p.marks.visible);
        }
        if (hasAppearance) {
            Theme.appearance = "drawing-board";
            for (const frame of [menu, dialog]) {
                const p = parts(frame);
                verify(p.shadow.hatched, "hatched on the board");
                compare(p.shadow.x, 4 * hair);
                verify(p.marks.visible, "crop marks on the board");
            }
            Theme.appearance = "";
        }
        menu.destroy(); dialog.destroy();
    }
}
