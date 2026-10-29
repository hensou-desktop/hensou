# Hensou

Hensou is a plain Qt Quick desktop kit with a standalone Rust/cxx-qt demo.
The same kit also serves Mountainous's existing Quickshell shell. The demo does
not require a Quickshell process. Files remains unimplemented; independent
products such as Pyxamp and Forgerie stay outside this repository.

Supported target: x86_64 Linux. Persisted appearance identifiers remain
`platinum` and `win98`, with five existing light/dark/extra-dark appearances.

| Directory | Responsibility |
| --- | --- |
| `kit/qml/Hensou` | Shared appearance values, tokens and drawing |
| `crates/theme-state` | Existing desktop theme-file contract |
| `crates/qt-host` | Native Qt watching, fonts and per-window DPR |
| `apps/demo` | Local fixture-backed interactive app composition |
| `nix/fonts.nix` | Independently packaged exact theme fonts |
| `tests/demo` | Real Wayland interaction and host acceptance harness |
| `tools/xtask` | Workspace formatting, Clippy and tests |

## Build and run

All heavy work runs on **Aka**, under the active workflow's shared heavy-job
wrapper, with remote Nix builders disabled. Do not evaluate, compile or render
locally. Do not run aggregate flake checks. Transfer committed snapshots by Git
bundle and verify their full source SHA before running commands.

Relevant individual commands **inside that remote wrapper**:

```sh
nix build --builders '' --max-jobs 1 --cores 2 .#hensou-qml
nix build --builders '' --max-jobs 1 --cores 2 .#hensou-demo
./result/bin/hensou-demo
```

The demo supports editable text, checkbox state, buttons, selectable scrolling
fixtures, an escaping native menu, modal dialog and second window. More exposes
empty/one/many fixtures and disabled states. Theme-file changes preserve edits,
selection and checkbox state.

See [host/runtime and focused tests](docs/host.md), [architecture](docs/architecture.md)
and [delivery phases](docs/phases.md). The fonts retain their upstream notices;
Qt, generated fonts and third-party binaries are not vendored. No release,
public upload or deployment is implied by this foundation work.
