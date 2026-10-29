# Standalone Qt host

Hensou's demo is one Rust/cxx-qt process with ordinary Qt Quick windows. It does
not start Quickshell. It has no service clients, sockets, network calls or Files
features. All controls consume the `Hensou` URI module; no directory imports
create alternate singleton identities.

## Packages and runtime paths

| Output (x86_64-linux) | Contract |
| --- | --- |
| `hensou-qml` | Independent plain module at `lib/qt-6/qml/Hensou`, including qmldir and generated resources |
| `hensou-demo` | Wrapped `bin/hensou-demo` and focused `bin/hensou-demo-tests` |
| `chicagoflf` | ChicagoFLF 2.1 and upstream public-domain statement |
| `w95fa-grid` | W95FA Grid 1.002-grid1 and unchanged SIL OFL |
| `hensou-fonts` | Both fonts at `share/fonts/truetype` |

The wrapper supplies `HENSOU_QML_IMPORT_PATH` (the parent of `Hensou/`) and
`HENSOU_FONT_DIRECTORY`. Qt's native application font database registers both
packaged faces before loading QML. This augments, rather than replaces, the
user's fallback fonts. Missing or wrong packaged font families fail startup.
The dev shell supplies the same fonts and one **merged Qt prefix** through
`QMAKE`. libglvnd supplies Qt's GLX/OpenGL link dependencies. The app and dev
shell use lld: cxx-qt 0.10 places initializer-call archives after their defining
archives, which requires order-independent ELF archive resolution. A qtbase-only qmake cannot resolve QtQml's PRL files.

The source inputs and font generator are copied from Mountainous
`a905fd62309a3027a654ce01a504d54540dc7f6a`. The lock retains its exact archive
hashes. No generated font binaries are committed. Mountainous can consume these
font outputs rather than maintaining a second generator.

## State and I/O

`hensou-theme-state` implements the existing three-file contract under
`$XDG_STATE_HOME/mountainous`, or `$HOME/.local/state/mountainous`:

| File | Valid values | Missing or invalid |
| --- | --- | --- |
| `theme-name` | `platinum`, `win98` | `platinum` |
| `theme` | `light`, `dark` | Keep current mode; startup `dark` |
| `theme-extra` | `on`, `off` | `off` |

Win98 retains the extra preference but does not apply it. `HostTheme` is an I/O
adapter, not a second drawing-token singleton. The composition root binds its
values to the single `Hensou.Theme`. QFileSystemWatcher watches files and their
containing directory, including atomic replacements. A 35 ms debounce
coalesces changes. A one-second recovery timer repairs deleted/recreated or
initially missing directories and transient watcher failures. The reader never
creates state directories or writes preferences. Parent-owned Qt objects stop
all watches and timers at engine destruction; there is no worker thread.

`NativeWindowMetrics` is a QQuickItem. It follows its own QQuickWindow, reads
`QWindow::devicePixelRatio()`, and reacts to `DevicePixelRatioChange`, show and
screen changes. Each window/popup provides a separate `Hensou.WindowScale`.
It never writes process-wide token geometry or reads rounded QScreen DPR.
This small native helper exists because that QWindow property is not available
as a reactive QML property on the supported Qt build.

## Demo composition

Demo files compose the existing themed atoms and drawing; they do not copy
bevels, font rasters or icon renderers. Each window owns fixture state outside
appearance Loaders: draft, cursor/selection, checkbox and selected row.
Switching drawing restores that state and semantic keyboard focus.

The Increment action changes a local count. More supplies empty/one/many
fixtures, disabled inputs, a native modal dialog and a second controls window.
Enter on a list row opens its complete label, including unbroken long labels.
The popup uses `Popup.Window`, not a clipped in-item menu. The modal dialog uses the standard Qt Quick Controls `Dialog` with
`Popup.Window`, a real native popup/grab and `modal: true`. A custom
QQuickWindow/WindowModal blocked pointer actions but could leave Sway focus on
the parent. The standard dialog avoids that keyboard trap. Closing either returns focus.

`LayoutPlan.js` owns the guessed container fit thresholds. Narrow-tall stacks
controls. Wide-short puts the form beside the list. At very small sizes the
primary actions remain and More opens a full controls window with the **same**
state, rather than removing editing or selection. Readouts yield before actions;
the count remains available in More. List scrolling is visible through the
kit's scrollbar and keyboard selection reveals the current row.

## Focused verification

All evaluation, builds, formatting, Clippy, tests and rendering run **only on
Aka** through the active run's shared `tools/heavy.sh`. No aggregate flake
checks. Copy automation scripts before running them. Invoke transfer scripts
locally with `bash` so their Nix shebang does not evaluate locally.

From a committed source snapshot on Aka, under the shared wrapper:

- `bash tools/build-native.sh`: Rust formatting, four theme-state tests,
  Cargo check and focused Clippy.
- `bash tools/test-demo.sh`: layout boundaries, compile the real app/test
  binary, then run native Qt Quick tests under isolated headless Wayland.
- `bash tools/check-style.sh`: focused Nix/Python/shell checks.
- `bash tools/test-package.sh`: build the independent package, clear borrowed
  Qt/library/font paths, then exercise its wrapped tests and actual app.
- `nix build --builders '' --max-jobs 1 --cores 2 .#hensou-qml`
- `nix build --builders '' --max-jobs 1 --cores 2 .#hensou-demo`

`tests/demo/run.py` records the full Hensou SHA and baseline Mountainous SHA,
logs, native/compositor geometry and images beneath the active run's `evidence/demo-SHA/`. It drives real
filesystem changes, native windows and two output scales. It does not use the
baseline's FONTCONFIG_FILE. The test binary uses the same compiled demo module
and native host as the executable. Real Wayland keyboard/pointer fixtures prove
a positive parent click, blocked click, native popup grabs and Escape/focus
return. Test-only synthetic Qt input is not evidence of native modal blocking.
Both the test and real app processes run with a finite timeout and grouped
cleanup of the private compositor/input devices. Parent runs the combined suite once.

For a deliberate Cargo.lock/format update, `tools/prepare-cargo.sh` only changes
a temporary copy. Bring its patch/lock back, commit them, transfer a new bundle,
and verify that immutable revision. Preparation output is not build evidence.
