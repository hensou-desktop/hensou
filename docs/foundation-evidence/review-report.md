## Review
**Merge verdict: OK with notes.**

### Must-fix
None found.

### Optional finding
- **P2 — Partial control-state preservation.** Contract: “Live theme settings changes preserve control state.” Hensou `apps/demo/qml/DemoField.qml:16–17` restores `cursorPosition`, then calls `select(selectionStart, selectionEnd)`. Qt 6.11.2’s `QQuickTextInputPrivate::setSelection` places the cursor at the second endpoint. Thus a backward selection becomes forward after switching themes. The selection range survives, but subsequent Shift+Arrow behavior changes. Source-verified against pinned Qt source; not runtime-reproduced. Smallest fix: restore selection with endpoint order determined by the saved cursor. Add a backward-selection regression; cost is one additional state-restoration case. Existing coverage at `tests/demo/tst_demo.qml:66–75` checks only forward selection bounds.

### Checks run
- Read fixed-range `git diff BASE...HEAD` and `git log --oneline BASE..HEAD` using the supplied full SHAs in both clean checkouts.
- Read the full contract, design handoff, required engineering documents, repository instructions, and applicable design skills.
- Inspected host/state/DPR code, native-input acceptance harnesses, shell adapters, packaging and all ten final packaged appearance screenshots.
- Read baseline web-theme failure evidence. No tests, builds, Nix evaluation, rendering or image comparisons ran.

### Correct
- Shared drawing remains separate from shell watchers, surfaces, focus grabs and service owners.
- Native metrics and nearest-provider lookup support independent per-window real DPR.
- Input evidence distinguishes server-observed grabs from the owner-input guard.
- Five appearances and external Pyxamp/Forgerie ownership remain intact. No concrete scope creep found.

### Unchecked limits
Parent-reported gates: Hensou passed; Mountainous passed 18/19. Web-theme remains red with the same baseline mismatch, not a new palette regression. Deployment was not checked. Platinum pixel identity remains unproven; documented baseline nondeterminism does not establish identity.
