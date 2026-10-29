# Architecture

## One repository, separate products

The Hensou monorepo holds the theme kit, shared Rust/Qt integration and desktop essentials such as Files and appearance settings. A shared control change can update its in-repository callers in one commit. Each desktop app has its own package and focused tests. Independent products consume a pinned Hensou release from their own repositories.

Mountainous remains a separate fleet and deployment repository. Its Quickshell shell imports the same Hensou QML kit as the apps. Pyxamp, Forgerie and the media services remain independent products. Their playback, authentication and service clients do not belong in the generic kit. Future catalog adapters belong to their consuming product unless real reuse justifies a separate SDK.

## Dependency direction

- Apps compose product behavior from shared crates and the kit.
- Shared crates and kit controls never import an app.
- Kit drawing uses plain Qt Quick and has no Quickshell imports.
- Each host supplies theme state to the kit. Quickshell watches state files in a shell-only adapter. A Rust app supplies its own adapter.
- Mountainous pins this repository as one flake input. Hensou does not import the Mountainous flake, which would create a cycle.

The selected app stack is Rust plus Qt Quick through cxx-qt. It is not Rust logic controlling an app hosted in a second Quickshell process. Files stays resident after its windows close so transfers can continue. A socket is reserved for external consumers such as desktop icons drawn by the shell, not required between Rust and its own QML.

## Extraction constraints

The foundation kit separates shared drawing from host I/O and compositor behavior. Each window supplies actual native DPR through WindowScale. Hosts own watching and popup lifetime. Preserve the shell's flat-file loading behavior and avoid duplicate singleton instances. See [the Qt host contract](host.md).

A standalone Rust/Qt demonstration app is the first independent host of the kit. It proves shared drawing, theme updates, focus, menus and scaling without services. Pyxamp adoption is optional work in its own repository, not a prerequisite for Files. Do not copy production code into empty crates merely to fill the directory layout.

## Builds

The flake supports x86_64-linux. It exports independent hensou-qml and hensou-demo packages plus shared theme-font packages. The dev shell supplies one merged Qt prefix, exact fonts and Rust tools.

A Cargo workspace provides one lockfile and can reuse a local target directory. It does not automatically provide shared Nix dependency derivations. Add a measured dependency-cache strategy when real apps enter the workspace. The scaffold promises neither a working Qt app nor a binary cache.

Run one relevant Nix attribute at a time with bounded jobs. Do not run aggregate flake checks on the fleet. CI is manual until its runner, secrets and budget policy are configured.
