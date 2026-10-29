# Delivery phases

Only phase 0 is covered by this scaffold. Every later phase ends with a buildable revision, review and verification of the deployed result. Do not change the running shell as part of repository setup.

## Phase 0: repository scaffold

- Create a private monorepo under hensou-desktop.
- Pin Nix and Rust, provide workspace checks and manual CI.
- Record architecture, scope and the unresolved theme branding.

## Phase 1: Hensou kit and shell integration

Extract plain Qt Quick drawing and tokens from Mountainous. Add the Rust/Qt template and theme-state adapter. Prove fractional scale, live switches, accessible controls and menus that escape their window.

Verify both existing themes and all five appearances against baseline shell screenshots. The full shell lifecycle tests must pass. Deploy through Mountainous with rollback available. No visible change is intended.

## Phase 2: Pyxamp migration

Import the existing app with its history and license notices. Move its face onto the shared kit. Extract library clients only with the consumer changes and fixture tests needed to prove parity. Keep playback behavior intact.

Review, build and deploy before Files depends on this runtime.

## Phase 3: Files local and SSH

Build the file windows in both themes, local and SFTP browsing, trusted host keys, copying, conflict handling, transfer lifetime, remote edit upload and Trash. Include folder-view memory and safe disk eject. Search, libraries and desktop icons are not part of this release.

Use temporary directories and an isolated SSH server for destructive-operation tests. Never use the owner's files as test fixtures.

## Phase 4: libraries

Add read-only catalog adapters for Pyxis, Ossicle, Comics and Jellyfin. Use shared secret-file configuration. Preserve the rule that opening uses desktop file handlers. Missing sizes show an unknown value, not zero.

The Comics original-download endpoint is work in its own repository. Complete that prerequisite before enabling open or copy for Comics items.

## Phase 5: desktop icons

Quickshell draws icons using the kit. Files supplies data and handles actions over a versioned local interface. Include Desktop folder contents, computer/drives, one SSH Hosts entry, libraries and Trash. Remember positions and move icons back into view after display changes.

## Review and release rules

Each phase owns focused tests. One integrator runs the combined relevant suite once; reviewers run focused checks. Use actual Myoko screenshots before claiming a deployment is verified. A build alone is not deployment proof.

Repository creation does not authorize transferring or archiving Pyxamp, publishing releases, configuring organization runners or deploying new services. Those operations are separate from the scaffold.
