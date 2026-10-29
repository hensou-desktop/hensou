# Delivery phases

Phase 0 created the scaffold. Phase 1 builds the kit, standalone demo and unchanged-shell integration. Every phase ends with a buildable revision, review and deployment evidence where authorized.

All compilation, Nix evaluation/builds, test suites, VM tests and headless rendering run on Aka under one shared heavy-job lock. Local machines edit and coordinate. Myoko only receives finished closures and runs light deployment checks. No local-build fallback is allowed. Never run aggregate flake checks.

## Phase 0: repository scaffold

- Create a private monorepo under hensou-desktop.
- Pin Nix and Rust, provide workspace checks and manual CI.
- Record architecture, scope and the unresolved theme branding.

## Phase 1: Hensou kit and shell integration

Extract plain Qt Quick drawing and tokens from Mountainous. Add the Rust/Qt template and theme-state adapter. Prove fractional scale, live switches, accessible controls and menus that escape their window.

Verify both existing themes and all five appearances against baseline shell screenshots. The full shell lifecycle tests must pass. Deploy through Mountainous with rollback available. No visible change is intended.

## Foundation proof: standalone demo

Phase 1 includes a normal Rust/Qt demo as an independent kit consumer. Exercise real controls and fixture state, live switching, keyboard access, popup hosts and per-window scale. It contacts no backend services.

Pyxamp stays in its own repository. Hensou does not import its history, face, playback behavior or service clients. Pyxamp can adopt the kit later without blocking Files.

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
