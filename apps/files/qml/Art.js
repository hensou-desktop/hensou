.pragma library
// Files' own theme art: kind icons, alert icons and the Explorer toolbar.
// Drawn for Hensou in each theme's idiom (Mac OS 8 Platinum, the Memphis
// 16-colour set); never Adwaita or hicolor. #000001 is the outline ink:
// black on light faces, Win98Tokens.ink on Memphis dark grey.
//
// INTEGRATE(file-icons): hensou_file_icons resolves exact theme icons for a
// MIME type; until it is wired, kinds map to these generic pictures.

var S = '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32" shape-rendering="crispEdges">';
var E = '</svg>';

// Mac OS 8 shapes: a lavender folder, a dog-eared page, grey hardware.
var PAGE_P = '<path d="M6.5 2.5 H20.5 L26.5 8.5 V29.5 H6.5 Z" fill="#ffffff" stroke="#000001"/><path d="M20.5 2.5 V8.5 H26.5" fill="#cccccc" stroke="#000001"/>';
var platinum = {
    folder: S + '<path d="M2.5 7.5 H11.5 L13.5 9.5 H29.5 V27.5 H2.5 Z" fill="#a9a9f5" stroke="#000001"/><rect x="3" y="11" width="26" height="1" fill="#dcdcff"/><rect x="3" y="12" width="1" height="15" fill="#dcdcff"/><rect x="3" y="26" width="26" height="1" fill="#6b6bc4"/><rect x="28" y="12" width="1" height="15" fill="#6b6bc4"/><rect x="2" y="10" width="28" height="1" fill="#000001"/>' + E,
    home: S + '<path d="M2.5 7.5 H11.5 L13.5 9.5 H29.5 V27.5 H2.5 Z" fill="#a9a9f5" stroke="#000001"/><rect x="2" y="10" width="28" height="1" fill="#000001"/><path d="M16 12.5 L22.5 18 H20.5 V24.5 H11.5 V18 H9.5 Z" fill="#ffffff" stroke="#000001"/><rect x="15" y="20" width="2" height="4" fill="#6b6bc4"/>' + E,
    document: S + PAGE_P + '<rect x="9" y="12" width="14" height="1" fill="#999999"/><rect x="9" y="16" width="14" height="1" fill="#999999"/>' + E,
    text: S + PAGE_P + '<path d="M9 11.5 H23 M9 14.5 H23 M9 17.5 H23 M9 20.5 H23 M9 23.5 H18" stroke="#000001"/>' + E,
    image: S + PAGE_P + '<rect x="9.5" y="12.5" width="14" height="11" fill="#99ccff" stroke="#000001"/><path d="M10 23 L14 17 L17 21 L19 19 L23 23 Z" fill="#339933"/><rect x="18" y="14" width="3" height="3" fill="#ffcc00"/>' + E,
    audio: S + PAGE_P + '<path d="M13.5 23.5 V13.5 L21.5 11.5 V21.5" fill="none" stroke="#000001" stroke-width="1.5"/><ellipse cx="12" cy="23.5" rx="2.5" ry="2" fill="#000001"/><ellipse cx="20" cy="21.5" rx="2.5" ry="2" fill="#000001"/>' + E,
    video: S + PAGE_P + '<rect x="9.5" y="12.5" width="14" height="12" fill="#333333" stroke="#000001"/><path d="M11 14 h1 v1 h-1z M11 17 h1 v1 h-1z M11 20 h1 v1 h-1z M11 23 h1 v1 h-1z M21 14 h1 v1 h-1z M21 17 h1 v1 h-1z M21 20 h1 v1 h-1z M21 23 h1 v1 h-1z" fill="#ffffff"/><rect x="13" y="15" width="7" height="7" fill="#99ccff"/>' + E,
    archive: S + PAGE_P + '<rect x="9.5" y="15.5" width="14" height="6" fill="#cccccc" stroke="#000001"/><path d="M12 16 V21 M15 16 V21 M18 16 V21 M21 16 V21" stroke="#666666"/><rect x="14.5" y="13.5" width="4" height="10" fill="none" stroke="#000001"/>' + E,
    application: S + '<path d="M16 2.5 L29.5 16 L16 29.5 L2.5 16 Z" fill="#c9c9ff" stroke="#000001"/><path d="M16 6 L26 16 L16 26 L6 16 Z" fill="#a9a9f5"/><path d="M12 16 H20 M16 12 V20" stroke="#000001"/>' + E,
    computer: S + '<rect x="6.5" y="2.5" width="19" height="21" fill="#e8e4d8" stroke="#000001"/><rect x="9.5" y="5.5" width="13" height="10" fill="#7a7acc" stroke="#000001"/><rect x="10" y="6" width="12" height="2" fill="#a9a9f5"/><rect x="10" y="19" width="7" height="1" fill="#000001"/><rect x="5.5" y="23.5" width="21" height="5" fill="#d8d4c8" stroke="#000001"/><rect x="21" y="25" width="3" height="1" fill="#33aa33"/>' + E,
    disk: S + '<rect x="3.5" y="10.5" width="25" height="11" fill="#d6d6d6" stroke="#000001"/><rect x="4" y="11" width="24" height="1" fill="#ffffff"/><rect x="4" y="20" width="24" height="1" fill="#888888"/><rect x="22" y="16" width="3" height="2" fill="#33aa33"/><rect x="6" y="16" width="10" height="1" fill="#888888"/>' + E,
    removable: S + '<rect x="3.5" y="9.5" width="25" height="13" fill="#d6d6d6" stroke="#000001"/><rect x="4" y="10" width="24" height="1" fill="#ffffff"/><rect x="7.5" y="13.5" width="17" height="3" fill="#555555" stroke="#000001"/><rect x="22" y="19" width="3" height="1" fill="#33aa33"/><path d="M14 19.5 H18" stroke="#000001"/>' + E,
    network: S + '<circle cx="16" cy="16" r="12.5" fill="#99ccff" stroke="#000001"/><path d="M16 3.5 V28.5 M3.5 16 H28.5 M6 9.5 H26 M6 22.5 H26" stroke="#336699" fill="none"/><ellipse cx="16" cy="16" rx="5.5" ry="12.5" fill="none" stroke="#336699"/><path d="M9 8 Q12 11 10 15 Q13 19 11 24 L8 21 Q6 15 9 8 Z M20 7 Q25 10 24 15 L21 18 Q19 14 21 11 Z" fill="#339933"/>' + E,
    host: S + '<rect x="8.5" y="2.5" width="15" height="27" fill="#d6d6d6" stroke="#000001"/><rect x="9" y="3" width="14" height="1" fill="#ffffff"/><path d="M11 7.5 H21 M11 10.5 H21 M11 13.5 H21" stroke="#555555"/><rect x="19" y="25" width="2" height="2" fill="#33aa33"/><rect x="11" y="25" width="5" height="1" fill="#555555"/>' + E,
    trash: S + '<path d="M7.5 9.5 H24.5 L23 29.5 H9 Z" fill="#cfcfcf" stroke="#000001"/><path d="M12 12 V27 M16 12 V27 M20 12 V27" stroke="#888888"/><rect x="5.5" y="6.5" width="21" height="3" fill="#e0e0e0" stroke="#000001"/><rect x="13.5" y="4.5" width="5" height="2" fill="#e0e0e0" stroke="#000001"/>' + E,
    "trash-full": S + '<path d="M9 2.5 L15.5 1.5 L17 6 L10 7 Z" fill="#ffffff" stroke="#000001"/><path d="M17.5 3.5 L23.5 4.5 L22 7.5 L16.5 6.5 Z" fill="#ffffcc" stroke="#000001"/><path d="M7.5 9.5 H24.5 L23 29.5 H9 Z" fill="#cfcfcf" stroke="#000001"/><path d="M12 12 V27 M16 12 V27 M20 12 V27" stroke="#888888"/><rect x="5.5" y="6.5" width="21" height="3" fill="#e0e0e0" stroke="#000001"/>' + E,
    caution: S + '<path d="M16 2.5 L30.5 28.5 H1.5 Z" fill="#ffcc00" stroke="#000001"/><rect x="14.5" y="10" width="3" height="11" fill="#000001"/><rect x="14.5" y="23" width="3" height="3" fill="#000001"/>' + E,
    stop: S + '<path d="M10.5 1.5 H21.5 L30.5 10.5 V21.5 L21.5 30.5 H10.5 L1.5 21.5 V10.5 Z" fill="#dd2222" stroke="#000001"/><path d="M11 23 V12 M14 22 V9 M17 22 V9 M20 22 V11 M11 23 Q16 27 21 23 L23 17" stroke="#ffffff" stroke-width="2" fill="none"/>' + E,
    note: S + '<rect x="2.5" y="3.5" width="27" height="19" rx="4" fill="#ffffff" stroke="#000001"/><path d="M8 22.5 L6 29 L13 22.5" fill="#ffffff" stroke="#000001"/><rect x="15" y="7" width="2" height="2" fill="#000001"/><rect x="15" y="11" width="2" height="8" fill="#000001"/>' + E,
    key: S + '<circle cx="10" cy="16" r="6.5" fill="#ffcc00" stroke="#000001"/><circle cx="9" cy="16" r="2" fill="#ffffff" stroke="#000001"/><path d="M16.5 14.5 H29.5 V17.5 H27.5 V20.5 H24.5 V17.5 H16.5 Z" fill="#ffcc00" stroke="#000001"/>' + E
};

// The Memphis 16-colour set: yellow folders, white pages, grey hardware.
var PAGE_W = '<path d="M6.5 1.5 H20.5 L26.5 7.5 V30.5 H6.5 Z" fill="#ffffff" stroke="#000001"/><path d="M20.5 1.5 V7.5 H26.5" fill="#c0c0c0" stroke="#000001"/>';
var win98 = {
    folder: S + '<path d="M2.5 6.5 H12.5 L14.5 9.5 H28.5 V27.5 H2.5 Z" fill="#ffff80" stroke="#808000"/><path d="M3 11 H28" stroke="#ffffff"/><path d="M2.5 11.5 H29.5 L27.5 27.5 H2.5 Z" fill="#e0e060" stroke="#808000"/>' + E,
    home: S + '<path d="M2.5 6.5 H12.5 L14.5 9.5 H28.5 V27.5 H2.5 Z" fill="#ffff80" stroke="#808000"/><path d="M8.5 4.5 H20.5 V18.5 H8.5 Z" fill="#ffffff" stroke="#000001"/><path d="M10 8 H19 M10 11 H19 M10 14 H17" stroke="#000080"/><path d="M2.5 13.5 H29.5 L27.5 27.5 H2.5 Z" fill="#e0e060" stroke="#808000"/>' + E,
    document: S + PAGE_W + '<path d="M9 12.5 H23 M9 16.5 H23" stroke="#808080"/>' + E,
    text: S + PAGE_W + '<path d="M9 10.5 H23 M9 13.5 H23 M9 16.5 H23 M9 19.5 H23 M9 22.5 H23 M9 25.5 H17" stroke="#000080"/>' + E,
    image: S + PAGE_W + '<rect x="9.5" y="11.5" width="14" height="12" fill="#00ffff" stroke="#000001"/><path d="M10 23 L14 16 L17 20 L19 18 L23 23 Z" fill="#008000"/><rect x="18" y="13" width="3" height="3" fill="#ffff00"/>' + E,
    audio: S + PAGE_W + '<path d="M13.5 24.5 V13.5 L21.5 11.5 V22.5" fill="none" stroke="#000080" stroke-width="2"/><rect x="10" y="23" width="4" height="3" fill="#000080"/><rect x="18" y="21" width="4" height="3" fill="#000080"/>' + E,
    video: S + PAGE_W + '<rect x="9.5" y="11.5" width="14" height="13" fill="#000000" stroke="#000001"/><path d="M11 13 h1 v1 h-1z M11 16 h1 v1 h-1z M11 19 h1 v1 h-1z M11 22 h1 v1 h-1z M21 13 h1 v1 h-1z M21 16 h1 v1 h-1z M21 19 h1 v1 h-1z M21 22 h1 v1 h-1z" fill="#ffffff"/><rect x="13" y="14" width="7" height="8" fill="#0000ff"/>' + E,
    archive: S + '<path d="M2.5 6.5 H12.5 L14.5 9.5 H28.5 V27.5 H2.5 Z" fill="#ffff80" stroke="#808000"/><path d="M2.5 11.5 H29.5 L27.5 27.5 H2.5 Z" fill="#e0e060" stroke="#808000"/><path d="M15.5 11.5 V27.5" stroke="#000001"/><path d="M14 13 h3 M14 16 h3 M14 19 h3 M14 22 h3" stroke="#808080"/><rect x="13.5" y="23.5" width="4" height="3" fill="#c0c0c0" stroke="#000001"/>' + E,
    application: S + '<rect x="2.5" y="4.5" width="27" height="22" fill="#c0c0c0" stroke="#000001"/><rect x="3" y="5" width="26" height="4" fill="#000080"/><rect x="25" y="6" width="3" height="2" fill="#c0c0c0"/><rect x="4.5" y="10.5" width="23" height="14" fill="#ffffff" stroke="#808080"/>' + E,
    computer: S + '<rect x="4.5" y="2.5" width="23" height="18" fill="#c0c0c0" stroke="#000001"/><rect x="5" y="3" width="22" height="1" fill="#ffffff"/><rect x="7" y="5" width="18" height="13" fill="#000080"/><path d="M8 16 L12.5 9 L15 13 L17 10.5 L24 16 Z" fill="#1084d0"/><rect x="11.5" y="20.5" width="9" height="3" fill="#808080" stroke="#000001"/><rect x="2.5" y="24.5" width="27" height="5" fill="#c0c0c0" stroke="#000001"/><rect x="4" y="26" width="14" height="1" fill="#808080"/><rect x="24" y="26" width="3" height="2" fill="#00c000"/>' + E,
    disk: S + '<rect x="2.5" y="11.5" width="27" height="10" fill="#c0c0c0" stroke="#000001"/><rect x="3" y="12" width="26" height="1" fill="#ffffff"/><rect x="3" y="20" width="26" height="1" fill="#808080"/><rect x="24" y="16" width="3" height="2" fill="#00c000"/><rect x="5" y="16" width="12" height="1" fill="#808080"/>' + E,
    removable: S + '<rect x="2.5" y="10.5" width="27" height="12" fill="#c0c0c0" stroke="#000001"/><rect x="3" y="11" width="26" height="1" fill="#ffffff"/><rect x="6.5" y="14.5" width="15" height="3" fill="#000000" stroke="#808080"/><rect x="24" y="19" width="3" height="2" fill="#00c000"/>' + E,
    network: S + '<circle cx="16" cy="9" r="6.5" fill="#00ffff" stroke="#000001"/><path d="M11 6 Q14 8 12 11 L10 9 Z M17 4 Q21 6 20 9 L17 10 Z" fill="#008000"/><path d="M16 15.5 V20.5 M6.5 20.5 H25.5 M6.5 20.5 V22.5 M25.5 20.5 V22.5" stroke="#000001"/><rect x="1.5" y="22.5" width="10" height="8" fill="#c0c0c0" stroke="#000001"/><rect x="3" y="24" width="7" height="4" fill="#000080"/><rect x="20.5" y="22.5" width="10" height="8" fill="#c0c0c0" stroke="#000001"/><rect x="22" y="24" width="7" height="4" fill="#000080"/>' + E,
    host: S + '<rect x="4.5" y="4.5" width="23" height="17" fill="#c0c0c0" stroke="#000001"/><rect x="7" y="7" width="18" height="12" fill="#000080"/><rect x="11.5" y="21.5" width="9" height="3" fill="#808080" stroke="#000001"/><path d="M16 24.5 V28.5 M6.5 28.5 H25.5" stroke="#000001"/><rect x="9" y="9" width="8" height="1" fill="#ffffff"/><rect x="9" y="12" width="12" height="1" fill="#ffffff"/>' + E,
    trash: S + '<path d="M6.5 8.5 H25.5 L23.5 29.5 H8.5 Z" fill="#ffffff" stroke="#000001"/><path d="M9 11 L11 28 M12.5 11 L13.5 28 M16 11 V28 M19.5 11 L18.5 28 M23 11 L21 28 M7 14.5 H25 M7.5 19.5 H24.5 M8 24.5 H24" stroke="#808080"/><rect x="5.5" y="6.5" width="21" height="2" fill="#c0c0c0" stroke="#000001"/>' + E,
    "trash-full": S + '<path d="M9 1.5 L15.5 3.5 L13 8 L8 6 Z" fill="#ffffff" stroke="#000001"/><path d="M17.5 2.5 L24.5 3.5 L22 8 L17 7 Z" fill="#ffff80" stroke="#000001"/><path d="M6.5 8.5 H25.5 L23.5 29.5 H8.5 Z" fill="#ffffff" stroke="#000001"/><path d="M9 11 L11 28 M12.5 11 L13.5 28 M16 11 V28 M19.5 11 L18.5 28 M23 11 L21 28 M7 14.5 H25 M7.5 19.5 H24.5 M8 24.5 H24" stroke="#808080"/><rect x="5.5" y="6.5" width="21" height="2" fill="#c0c0c0" stroke="#000001"/>' + E,
    shortcut: '<svg xmlns="http://www.w3.org/2000/svg" width="11" height="11" viewBox="0 0 11 11" shape-rendering="crispEdges"><rect x="0.5" y="0.5" width="10" height="10" fill="#ffffff" stroke="#000001"/><path d="M3 8.5 V6 Q3 3.5 6 3.5 H7" fill="none" stroke="#000001" stroke-width="1.4"/><path d="M6 1.5 L9 3.5 L6 5.5 Z" fill="#000001"/></svg>',
    warning: S + '<path d="M16 1.5 L30.5 29.5 H1.5 Z" fill="#ffff00" stroke="#000001"/><rect x="14.5" y="9" width="3" height="12" fill="#000000"/><rect x="14.5" y="23" width="3" height="3" fill="#000000"/>' + E,
    error: S + '<circle cx="16" cy="16" r="13.5" fill="#ff0000" stroke="#000001"/><path d="M10.5 10.5 L21.5 21.5 M21.5 10.5 L10.5 21.5" stroke="#ffffff" stroke-width="3"/>' + E,
    question: S + '<path d="M3.5 3.5 H28.5 V21.5 H14 L7.5 28 V21.5 H3.5 Z" fill="#ffffff" stroke="#000001"/><path d="M12.5 9.5 Q12.5 6.5 16 6.5 Q19.5 6.5 19.5 9.5 Q19.5 11.5 16 13 V15" fill="none" stroke="#000080" stroke-width="2.5"/><rect x="14.5" y="16.5" width="3" height="3" fill="#000080"/>' + E,
    key: S + '<circle cx="10" cy="16" r="6.5" fill="#ffff00" stroke="#000001"/><circle cx="9" cy="16" r="2" fill="#ffffff" stroke="#000001"/><path d="M16.5 14.5 H29.5 V17.5 H27.5 V20.5 H24.5 V17.5 H16.5 Z" fill="#ffff00" stroke="#000001"/>' + E,
    // Explorer toolbar glyphs, 20 x 20 on the same grid.
    "tb-back": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><path d="M2.5 10 L9.5 3.5 V7.5 H17.5 V12.5 H9.5 V16.5 Z" fill="#00a000" stroke="#000001"/></svg>',
    "tb-forward": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><path d="M17.5 10 L10.5 3.5 V7.5 H2.5 V12.5 H10.5 V16.5 Z" fill="#00a000" stroke="#000001"/></svg>',
    "tb-up": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><path d="M1.5 6.5 H7.5 L8.5 8.5 H17.5 V17.5 H1.5 Z" fill="#ffff80" stroke="#808000"/><path d="M10 2.5 L14.5 7 H11.5 V14.5 H8.5 V7 H5.5 Z" fill="#000001"/></svg>',
    "tb-cut": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><path d="M7 1.5 L11 11 M13 1.5 L9 11" stroke="#000001" stroke-width="1.5"/><circle cx="6.5" cy="14.5" r="3" fill="none" stroke="#000080" stroke-width="1.5"/><circle cx="13.5" cy="14.5" r="3" fill="none" stroke="#000080" stroke-width="1.5"/></svg>',
    "tb-copy": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><rect x="1.5" y="1.5" width="10" height="12" fill="#ffffff" stroke="#000001"/><rect x="7.5" y="6.5" width="10" height="12" fill="#ffffff" stroke="#000001"/><path d="M9 9.5 H16 M9 12.5 H16 M9 15.5 H14" stroke="#000080"/></svg>',
    "tb-paste": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><rect x="1.5" y="3.5" width="12" height="15" fill="#c08040" stroke="#000001"/><rect x="4.5" y="1.5" width="6" height="3" fill="#c0c0c0" stroke="#000001"/><rect x="7.5" y="7.5" width="10" height="11" fill="#ffffff" stroke="#000001"/><path d="M9 10.5 H16 M9 13.5 H16" stroke="#000080"/></svg>',
    "tb-delete": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><path d="M4 4 L16 16 M16 4 L4 16" stroke="#ff0000" stroke-width="3"/></svg>',
    "tb-properties": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><rect x="2.5" y="2.5" width="15" height="15" fill="#ffffff" stroke="#000001"/><rect x="3" y="3" width="14" height="3" fill="#000080"/><path d="M5 9.5 H8 M10 9.5 H15 M5 12.5 H8 M10 12.5 H15 M5 15.5 H8 M10 15.5 H13" stroke="#000001"/></svg>',
    "tb-views": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><rect x="2.5" y="2.5" width="6" height="6" fill="#ffff80" stroke="#000001"/><rect x="11.5" y="2.5" width="6" height="6" fill="#ffff80" stroke="#000001"/><rect x="2.5" y="11.5" width="6" height="6" fill="#ffff80" stroke="#000001"/><rect x="11.5" y="11.5" width="6" height="6" fill="#ffff80" stroke="#000001"/></svg>',
    "tb-more": '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" shape-rendering="crispEdges"><path d="M5 6 L9 10 L5 14 M10 6 L14 10 L10 14" fill="none" stroke="#000001" stroke-width="1.5"/></svg>',
    "tree-plus": '<svg xmlns="http://www.w3.org/2000/svg" width="9" height="9" viewBox="0 0 9 9" shape-rendering="crispEdges"><rect x="0.5" y="0.5" width="8" height="8" fill="#ffffff" stroke="#808080"/><path d="M2 4.5 H7 M4.5 2 V7" stroke="#000001"/></svg>',
    "tree-minus": '<svg xmlns="http://www.w3.org/2000/svg" width="9" height="9" viewBox="0 0 9 9" shape-rendering="crispEdges"><rect x="0.5" y="0.5" width="8" height="8" fill="#ffffff" stroke="#808080"/><path d="M2 4.5 H7" stroke="#000001"/></svg>'
};

function svg(theme, name) {
    var set = theme === "win98" ? win98 : platinum;
    if (set[name]) return set[name];
    // Alert names differ per idiom; each set answers the other's.
    var aliases = theme === "win98"
        ? { caution: "warning", stop: "error", note: "question" }
        : { warning: "caution", error: "stop", question: "note", disk: "disk" };
    if (aliases[name] && set[aliases[name]]) return set[aliases[name]];
    return set.document;
}

function hex2(n) { var h = Math.max(0, Math.min(255, Math.round(n))).toString(16); return h.length < 2 ? "0" + h : h; }
function mix(color, toward, amount) {
    var a = /^#([0-9a-f]{6})$/i.exec(color), b = /^#([0-9a-f]{6})$/i.exec(toward);
    if (!a || !b) return color;
    var x = parseInt(a[1], 16), y = parseInt(b[1], 16);
    var r = ((x >> 16) & 255) * (1 - amount) + ((y >> 16) & 255) * amount;
    var g = ((x >> 8) & 255) * (1 - amount) + ((y >> 8) & 255) * amount;
    var bl = (x & 255) * (1 - amount) + (y & 255) * amount;
    return "#" + hex2(r) + hex2(g) + hex2(bl);
}

// tint: a selected icon takes the selection colour (Memphis) or darkens
// (Platinum), as each OS drew a selected icon.
function url(theme, name, ink, tint) {
    var text = svg(theme, name).replace(/#000001/g, String(ink || "#000000"));
    if (tint) {
        var toward = theme === "win98" ? String(tint) : "#000000";
        text = text.replace(/(fill|stroke)="(#[0-9a-fA-F]{6})"/g, function(m, attr, color) {
            return attr + '="' + mix(color, toward, 0.45) + '"';
        });
    }
    return "data:image/svg+xml;utf8," + encodeURIComponent(text);
}
