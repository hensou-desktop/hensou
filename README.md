# Hensou

Hensou is a shared desktop kit and app workspace for Linux. Rust apps use Qt Quick through cxx-qt and share their theme drawing with the Quickshell desktop shell.

**This repository is a scaffold.** The workspace checks build and run. The QML kit and Files are not implemented yet. Pyxamp stays in its own repository and is not part of this monorepo. No running desktop has changed.

## Work locally

Supported initial target: x86_64 Linux. Nix pins the Rust and Qt tools to the same nixpkgs revision as Mountainous.

```sh
nix develop -c cargo xtask check
nix build .#hensou-xtask --max-jobs 1 --cores 2
./result/bin/xtask --help
```

Without Nix, rustup reads rust-toolchain.toml. Run cargo xtask check from the repository root. The current tests need no Qt runtime or display.

## Layout

| Directory | Responsibility | Current state |
| --- | --- | --- |
| kit/qml/Hensou | Shared theme state, tokens and controls | Planned |
| crates | Shared Rust runtime and library clients | Planned |
| apps/files | Local and SSH file manager | Planned |
| tools/xtask | Formatting, Clippy and workspace tests | Runnable |
| docs | Architecture, design and delivery phases | Written |

See [architecture](docs/architecture.md), [delivery phases](docs/phases.md) and [Files design](docs/design/files.md).

## CI and distribution

Verify scaffold is a manual GitHub Actions workflow. It does not run on pushes or pull requests and has not been dispatched. It uses a GitHub-hosted Linux runner when dispatched, so private-repository minutes apply. A self-hosted runner is not configured here.

There are no release uploads, deployment credentials, Actions caches or artifact uploads. The Nix package is a development tool, not a finished app. Mountainous will consume one pinned Hensou input when the kit is ready.

Original scaffold code is MIT licensed. Future imports must retain their original licenses, notices and history. No fonts, third-party icons or Qt binaries are vendored here.
