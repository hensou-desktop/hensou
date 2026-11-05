// PROTOTYPE — fake Files data, including the stress set.
.pragma library

var hosts = [
    { name: "This computer", kind: "local", detail: "214 GB free" },
    { name: "aka", kind: "ssh", detail: "SSH" },
    { name: "myoko", kind: "ssh", detail: "SSH" },
    { name: "kuro", kind: "ssh", detail: "Host key changed" },
    { name: "Trash", kind: "trash", detail: "12 items" }
];

var ideal = [
    { name: "apps", kind: "dir", size: "4 items", date: "Nov 4 18:02" },
    { name: "crates", kind: "dir", size: "2 items", date: "Nov 3 09:41" },
    { name: "docs", kind: "dir", size: "6 items", date: "Nov 4 17:55" },
    { name: "kit", kind: "dir", size: "1 item", date: "Oct 30 22:10" },
    { name: "Cargo.toml", kind: "toml", size: "1.2 KB", date: "Nov 1 11:03" },
    { name: "Cargo.lock", kind: "lock", size: "88.4 KB", date: "Nov 1 11:03" },
    { name: "flake.nix", kind: "nix", size: "6.1 KB", date: "Oct 31 08:20" },
    { name: "README.md", kind: "md", size: "2.9 KB", date: "Oct 29 14:47" },
    { name: "a-very-long-filename-with-no-break-points-from-a-camera-export-IMG_20261104_235959_HDR_FINAL_v3.jpeg", kind: "jpeg", size: "48.2 GB", date: "Nov 4 23:59" },
    { name: ".envrc", kind: "", size: "0 B", date: "Oct 28 20:58" },
    { name: "broken-link", kind: "link", size: "Unknown", date: "Unknown" },
    { name: "rust-toolchain.toml", kind: "toml", size: "96 B", date: "Oct 28 21:30" },
    { name: "LICENSE", kind: "", size: "1.1 KB", date: "Oct 28 20:58" },
    { name: "notes-2026-11.txt", kind: "txt", size: "14 KB", date: "Nov 5 01:05" }
];

var column1 = [
    { name: "code", kind: "dir" }, { name: "Desktop", kind: "dir" },
    { name: "Documents", kind: "dir" }, { name: "Downloads", kind: "dir" },
    { name: "Music", kind: "dir" }, { name: "Pictures", kind: "dir" }
];
var column2 = [
    { name: "github", kind: "dir" }, { name: "hensou", kind: "dir" }, { name: "sandbox", kind: "dir" }
];

function entries(set) {
    if (set === "empty") return [];
    return ideal;
}
