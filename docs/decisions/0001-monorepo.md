# One monorepo for Hensou apps

Hensou's kit, shared Rust code, Files, Pyxamp and future themed apps live in hensou-desktop/hensou. Theme and API changes can update their consumers atomically. Mountainous and the backend services stay separate.

This supersedes the earlier proposal for separate Files and kit repositories. The cost is coordinated releases and a growing workspace. It does not mean every app must rebuild for every change, or that Cargo automatically shares Nix build derivations.
