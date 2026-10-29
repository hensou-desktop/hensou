# Hensou QML foundation

Import `Hensou` from `kit/qml`. Do not directory-import this module or copy its
singletons into a host. `qmldir` is the explicit public entry point.

This is an extraction of Mountainous a905fd62309a3027a654ce01a504d54540dc7f6a,
not a visual revision. Platinum keeps ChicagoFLF, #dddddd/#3a3a3a menu faces,
#333399/#5858d0 selection and its existing bevels. Win98 keeps W95FA Grid,
#c0c0c0/#3c3c3c faces and #000080/#41608a selection. Dimensions, paint order,
fonts and glyph artwork come from those controls. No new aesthetic references.

## Boundary

- `Theme` holds appearance values only: `name`, `mode`, `extraState`, derived
  `dark`/`extraDark` and the existing neutral palette. Hosts own persistence,
  validation, watchers, registry recovery, sounds, focus grabs and services.
- Each visual window provides `WindowScale { devicePixelRatio: nativeRatio }`
  as an ancestor. Optional `hostWindow` can supply an exposed native DPR.
  No Screen DPR and no singleton DPR writes. Missing-provider fallback is 1.5
  for legacy out-of-window drawing; a real host must bind a provider.
  Shell flat subclasses carry `hensouDevicePixelRatio` directly instead.
- `WindowScale.iconResolver(name, checkOnly=false)` optionally resolves system-theme icon URLs.
  `checkOnly:true` requests an empty URL for missing theme art (menu document
  fallback); false allows the host's ordinary app fallback. One-argument
  callbacks remain compatible. Without it built-in glyphs still work; system-theme icons have no source.
- Tokens are one module singleton per engine. Legacy `pixelRatio`, `u`, `hair`
  scalar properties are compatibility fallbacks only. Shared drawing uses the
  nearest provider. Shell drawing uses per-window token helpers.
- Assets are the glyphs enumerated by the existing icon stores, not the mock,
  gallery, thumbnails or service-specific screens. `resources.js` embeds their
  SVG text. No file reader, XHR permission or shell-root path is required.

## Controls

The module exports the existing Platinum and Win98 button, field, checkbox,
list/row, bevel, scrollbar, icon and menu/dialog frame types. Their original
properties remain. `qmldir` lists the selected support types too.

- Buttons: `text`, `clicked()`, Space/Enter, disabled, focus and accessibility.
  Platinum's `keyboardEnabled` defaults true; the shell disables it to preserve
  its menu host's keyboard ownership. Existing `focused` remains available.
- Both fields: `text`, `input` (the real TextInput), `edited(string text)`,
  `keyPressed(event)`. Win98 also keeps `placeholder`, `accepted()` and its
  original input aliases. Set `Accessible.name` on the field.
- Checkboxes: `text`, `checked`, `toggled(bool checked)` emits the next value,
  without changing owner-bound state. Existing Win98 handlers that ignore the
  argument and invert their owner still work. Platinum's `interactive:false`
  keeps its original drawing-only behavior; apps set true. Shell adapters
  explicitly keep the primitive noninteractive. Both expose checked/name/role.
- Lists: `model`, `delegate`, `view`, `currentIndex`, `count`; rows retain their
  original properties. `PlatinumMenuList.activated(index)` is additive. Hosts
  supply selection data and activation; list scrolling preserves focus reveal.
  Platinum's Home/End/Page keys are enabled by `extendedNavigationEnabled:true`;
  the shell adapter sets false to preserve its menu host's key ownership.
- `Win98Text.wrapMode` defaults to Text.WordWrap. With `wrap:true`, app
  dialogs can request Text.WrapAnywhere for raw paths without modifying data.
- `Win98MenuPanel` exposes PopupMenu and its existing action delegates expose
  MenuItem semantics with access marks removed from names. Their disabled
  accessibility target is separate from the original hover surface, so disabled
  rows can still be highlighted by the shell without activation. Separators are
  ignored; `header:true` is non-actionable. Accessible press uses the same
  `clicked(index)` path, with no new MouseArea or keyboard owner.
- `PlatinumMenuListRow` stays ListItem for collections. Menu hosts override its
  existing `Accessible.role` to MenuItem; accessible press routes to `clicked()`
  and respects `enabled`. Frame names/PopupMenu and dialog roles are supplied.
- Frames only draw. Native menu escape, modality and focus return are host
  composition, not shell dependencies hidden in the kit.

No layout reconstructs children when size or appearance changes. Lists scroll
when their collection exceeds their region. Labels elide; hosts must expose the
full value (for example in a selected-row detail/dialog). No new motion.

## Focused validation

`python3 kit/generate-resources.py` regenerates `kit/qml/Hensou/resources.js`;
`--check` verifies it. `python3 kit/check-boundary.py` checks isolation and the
explicit module entry point. Run `qmltestrunner -input kit/qml/Hensou/tests`
with `QML2_IMPORT_PATH=kit/qml` and the packaged Qt environment. The control
fixtures cover two independent scales, keys, disabled, owner state, live
appearance and 0/1/100 rows. The consuming demo owns the full view stress set
(blank/loading/partial/error/ideal, long words and mixed numeric/missing data),
and native popup/modal behavior. All workflow heavy checks execute on Aka.
