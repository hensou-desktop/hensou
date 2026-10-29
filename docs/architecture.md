# Architecture

## One repository, separate products

The Hensou monorepo holds the theme kit, shared Rust crates and themed apps. A theme or client change can update every caller in one commit. Each app will still have its own Nix package and focused tests.

Mountainous remains a separate fleet and deployment repository. Its Quickshell shell will import the same Hensou QML kit as the apps. Pyxis, Ossicle, Comics, Jellyfin and the Forgerie server remain separate services. Their clients belong here, not their servers.

## Dependency direction

- Apps compose product behavior from shared crates and the kit.
- Shared crates and kit controls never import an app.
- Kit drawing uses plain Qt Quick and has no Quickshell imports.
- Each host supplies theme state to the kit. Quickshell watches state files in a shell-only adapter. A Rust app supplies its own adapter.
- Mountainous pins this repository as one flake input. Hensou does not import the Mountainous flake, which would create a cycle.

The selected app stack is Rust plus Qt Quick through cxx-qt. It is not Rust logic controlling an app hosted in a second Quickshell process. Files stays resident after its windows close so transfers can continue. A socket is reserved for external consumers such as desktop icons drawn by the shell, not required between Rust and its own QML.

## Extraction constraints

The kit does not exist yet. Before adopting it, fix per-window fractional scale at 1.5, separate Quickshell-specific theme watching and icons, and implement app popup hosts. Preserve the shell's flat-file loading behavior and avoid duplicate singleton instances.

The first real consumer is Pyxamp. Import it with attribution and history before replacing its face and clients. Do not copy production code into empty crates merely to fill the directory layout.

## Builds

The initial flake supports x86_64-linux. The dev shell supplies one merged Qt prefix and Rust tools. The runnable package currently builds only the verification tool.

A Cargo workspace provides one lockfile and can reuse a local target directory. It does not automatically provide shared Nix dependency derivations. Add a measured dependency-cache strategy when real apps enter the workspace. The scaffold promises neither a working Qt app nor a binary cache.

Run one relevant Nix attribute at a time with bounded jobs. Do not run aggregate flake checks on the fleet. CI is manual until its runner, secrets and budget policy are configured.
