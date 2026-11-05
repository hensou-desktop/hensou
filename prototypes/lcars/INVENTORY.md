# PROTOTYPE: the live desktop, mapped to LCARS

Source: Mountainous `cairn` at `8c225385` (`modules/quickshell/`,
`modules/hyprland/hyprland.lua`, `docs/plans/desktop-themes.md`). Read from
code, not from a running session. Render states are in `shell/` and
`shots/shell-<state>.png`.

## Bar (Platinum top bar, Win98 taskbar and tray)

| Live item | What it does today | LCARS form | Rendered |
|---|---|---|---|
| Apple menu / Start menu | About host, Control Panels (Appearance, Bluetooth, Brightness, Remote builds, Sound, Wi-Fi), Recent apps, web apps, Find, Lock, Sleep, Log Out, Restart, Shut Down. Win98 adds Programs, Favorites, Documents, Windows, Commands, Settings, Run | The top elbow, labelled with the host name, opens a sub-frame | `system` (Programs, Favorites, Documents, Run and Interface scale not drawn) |
| Window title, Application menu | Front window title; Hide, Hide Others, Show All, running apps with their windows | Title segment holds the focused window's full title. App switching is the Super+Tab band | `calm`, `switch` (Hide rows not drawn) |
| Layout control | Tiled or floating, windows per page, outer gap, zen margins; This page and Default tabs | Segment "Tiled"; panel grows from it | `layout` |
| Bluetooth, Wi-Fi, Sound, Brightness | Hardware menus | Segments; panels grow from them | `sound`, `wifi` (Bluetooth and Brightness not drawn) |
| Cloud (OCI egress), Disks, Fleet, Builds | Quiet glyphs; a readout only while it warns | Same rule: a label when calm, label plus value in gold or red when it warns | `warn` |
| Notifications control | Count while unread or unsynced; opens the centre | "Comms" segment and the comms block in the arm | `notify`, `unread`, `critical` |
| Clock | Time; date and "Extra dark" in its menu | Clock segment; panel not drawn | `calm` |
| Battery | Fill; percent only when low | End cap of the bar; fill, number only when low | `calm`, `warn` |
| » overflow | Controls that do not fit, by name | "More n" segment, same OVERFLOW_ORDER | `warn`, `small` |
| Super+O chord | Key caps for B W S L C D F R Y N | Letters light on each segment; key list along the bottom bar | `chord` |
| Volume tag (1.5 s) | Level under the control after a key press | The segment shows its value | `sound` |
| Dictation (Right Alt) | Recording, working, done, failed; Retry and Dismiss | Arm filler turns red with the live level; bottom bar says where text goes | `dictation` |

## Desktop

| Live item | What it does today | LCARS form | Rendered |
|---|---|---|---|
| Control Strip / Win98 taskbar | Every window on this screen across pages; click, middle-click close, drag to move or swap; tile menu | The arm: one block per window, page dividers, focus gold, other pages dim, hidden marked | every state (tile menu not drawn) |
| Pages | No numbers, ever; named by their apps | Slim divider bars in the arm; no labels | every state |
| Desktop pattern | Tiled pattern per theme and appearance | Plain black (Myoko is OLED) | every state |
| Glance space (Super+W), Fleet window (Super+B), Disks widget | Fleet hosts with CPU, memory, disk; storage findings | Work area recedes under a grid; Fleet and Disks as sub-frames | `glance` |
| Find (Super+P, F1) | Omni lists: All, Applications Ctrl+1, Windows Ctrl+2, Commands Ctrl+3, Address Ctrl+L | Console with scope blocks in its arm | `find` |
| Super+Tab | Cycles apps (Win98 Cool Switch) | A band of app blocks with window counts; the target's windows below | `switch` |
| Notifications | Popups by urgency, notification centre | Pass 3: bottom readout, arm block that grows, red frame | `notify`, `unread`, `critical` |
| Session alerts | Log Out, Restart, Shut Down confirmations | Red sub-frame; Cancel is the default | `shutdown` |
| Second screen | Portable monitor above the panel; tablet below over Moonlight | One full frame per screen, its own windows | `dual`, `small` |
| Title bars (hyprbars) | Platinum and Win98 bars on every window | None. Dim border, gold when focused | every state |

## Not drawn yet

- Theme picker (Display…, Appearance…): LCARS would be a third entry.
- Theme sounds: menu open, choose, alert, beep, critical, notification,
  empty trash, minimise, restore. LCARS needs its own set.
- Icons and cursors: both themes ship sets; LCARS needs one or none.
- Window motion (minimise, restore, menus): not specified.
- Lock screen and boot: not checked.
- Pyxamp: each theme picks a player face (`platinum`, `winamp`); LCARS needs one.
- Native GTK, Qt and Ghostty themes: colours only.
- Web theme: postponed.
