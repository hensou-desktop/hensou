## Review

**Merge verdict: OK with notes.** No P0/P1 standards findings.

- **Checks run:** Fixed-range `watchdog_diff`/`git diff` and `git log --oneline` succeeded for both repositories. Hensou source reads used `git show ce52d491…:PATH`. `git rev-parse HEAD` confirmed Mountainous `429802b7…`. Read the full review briefs, contract, engineering documents, repository rules and UI skills.

- **Correct:** Shared drawing has no Quickshell dependency. Shell adapters preserve host-owned persistence and input policy. Their small subclasses are explicitly justified by Mountainous `docs/decisions/hensou-foundation.md`; I do not classify that repetition as a violation.

### Documented-standard breaches — P2

1. **Tests depend on private rendering structure.** Hensou `kit/qml/Hensou/tests/tst_controls.qml:160–168` traverses `"label.children[0].children"` and selects an internal Text object. Canonical `standards.md`, **Testing posture**, requires public-contract behavior tests, not private implementation shape. Assert wrapping through exposed dimensions and text-preservation behavior instead. Cost: replace the measurement assertions without weakening wrapping coverage.

2. **New layout sizes bypass tokens without explanation.** Hensou `apps/demo/qml/DemoDialog.qml:20–21` uses `"width: 440"` and `"height: 240"`; `DemoWindow.qml:29–32` similarly introduces four literal window limits. Canonical `style-guide.md`, **Visual design**, requires tokens or an inline explanation when no token fits. Name the demo sizing policy or explain these choices inline. This does not require changing appearance.

3. **Scale comments describe removed ownership.** Hensou `kit/qml/Hensou/PlatinumTokens.qml:39` says PlatinumTopBar keeps `pixelRatio` current. Mountainous `modules/quickshell/PlatinumMotionLayer.qml:24` repeats that claim. The diff removes those singleton writes. Canonical `style-guide.md`, **Comments**, requires current comments. Delete or update both; no runtime change is needed.

### Optional heuristic

- **Primitive Obsession:** Hensou `crates/theme-state/src/lib.rs:6–8` models appearance choices as public `&'static str` fields. Small enums could prevent invalid Rust-side values. Cost: additional conversion at the QString/persistence boundary. This is not a hard violation.

- **Not verified:** No builds, tests, Nix, rendering or image comparisons ran, as instructed. Parent-reported verification remains qualified: Mountainous 18/19 affected checks pass; `web-theme` remains red identically on baseline.
