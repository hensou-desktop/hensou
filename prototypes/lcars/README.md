# PROTOTYPE: LCARS look for Hensou Files

Throwaway spike. It lives only on the `spike/lcars-ui` branch and must not
land on `main`: ADR 0002 lists LCARS as out of scope. If LCARS becomes a
real theme, change that ADR first. The theme would then also fall under the
tandem rule: every feature ships in every theme.

Question: what would the planned Files window (local and SSH hosts, see
`docs/design/files.md`) look like in LCARS, and can plain Qt Quick draw it?

## Run

```sh
./render.sh            # every variant across the size ladder into shots/
./render.sh run B      # interactive window; ← and → switch variants
```

The script downloads the Antonio font (SIL OFL) into `fonts/` the first time.

## Variants

| Key | Name | Structure |
|-----|------|-----------|
| A | Console | One elbow. Hosts stacked in the left arm. The transfer runs along the bottom elbow. |
| B | Split | TNG double frame. Upper frame: hosts, path, transfer. Lower frame: list, with actions and readouts in its arm. |
| C | PADD | No elbows. Clickable path segments, Miller columns, hosts in a bottom console strip. |

All three share `plan.js`, a pure `plan(width, height)` function. Every
threshold in it is a guess until someone measures it in a real Hensou window.

## Findings

- Qt Quick 6.10 draws LCARS with no custom code: per-corner `Rectangle` radii
  make the elbows and pills. Shapes are not needed.
- Only chrome is upper case. File names keep their case, because file names
  are case-sensitive.
- Not built: keyboard focus, motion, sound, light appearance, and a real model.

## Pass 2: the whole desktop (`desktop/`)

`desktop/render.sh` renders `shots/desktop-*.png`: working, notification,
Super+Tab, laptop plus tablet, and 1280×800. The shell draws one frame per
screen and apps tile inside it with no title bars. The arm is the window
list; the top bar carries pages, the focused window's title and the clock.

Findings:

- With no title bars, tiles that are black (terminal, Files) melt into the
  black frame. A Hyprland border fixes it: dim when inactive, gold when focused.
- The focused window's full title needs a home; the top bar's long segment
  holds it, and a notification takes that segment over until it is read.
- Web pages keep their own colours and body face. Only scroll bars and form
  controls take LCARS. Making page text Antonio would hurt reading.

## Pass 3: notifications in the frame, and a browser extension

Notifications follow the freedesktop urgency the notification model already
keeps (`notification-model.js`: low 4 s, normal 7 s, critical never):

- low: one more readout segment in the bottom bar;
- normal: the arm's comms block grows out across the work area, then folds
  back into a counted block under the window list;
- critical: the whole frame turns alert red until acknowledged.

Periwinkle is reserved for comms, so no app block uses it.

`desktop/ReaderPage.qml` mocks what an extension content script could do to
an article: contents from its headings, LCARS headings and code boxes, body
in a readable face. The origin stays in the shell's top bar.

## Pass 4: shell sweep (`shell/`, `INVENTORY.md`)

`INVENTORY.md` maps every live desktop item (Mountainous `cairn` 8c225385)
to an LCARS form. `shell/render.sh` renders 17 states at Myoko's logical
1920×1200: calm, warn, chord, system, sound, wifi, layout, find, switch,
glance, dictation, notify, unread, critical, shutdown, dual, small.
The web theme is postponed: pages render untouched.
