# Files

The resident Hensou file manager: one Rust/cxx-qt process with Qt Quick
windows in both themes. Design: ../../docs/design/files.md.

```
hensou-files                 open the Computer window
hensou-files PATH|URI...     open folders (file://, sftp://host/path, ssh://host)
hensou-files --daemon        start without windows
hensou-files --fixture       use the fixture service (also HENSOU_FILES_BACKEND=fixture)
```

A second launch hands its request to the running instance over
`$XDG_RUNTIME_DIR/hensou/files.sock` and exits 0. The process stays alive
after its windows close and shows a StatusNotifierItem (`hensou-files`) while
transfers run.

| Path | What |
| --- | --- |
| `src/cli.rs`, `src/instance.rs` | command line and single-instance handoff |
| `src/seam.rs` | service choice; the Integrate seam for files-core and the desktop provider |
| `src/bridge.rs` | the QML singleton: files-model JSON in and out |
| `src/scenario.rs` | the fixture service used by `--fixture` and the tests |
| `src/hyprland.rs` | window placement through Hyprland IPC |
| `src/native.*`, `src/tray.*` | drag, clipboard, residency; the StatusNotifierItem |
| `qml/Model.js`, `qml/LayoutPlan.js`, `qml/Alerts.js` | pure view model, layout plan and alert wording |
| `qml/*.qml` | windows and controls composed from the Hensou kit |

Tests: `cargo test -p hensou-files`, `node tests/files/model.test.js`, and the
Qt Quick suite through `tools/test-files.sh` on Aka.
