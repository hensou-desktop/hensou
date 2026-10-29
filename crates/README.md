# Shared Rust code

Create a crate only when a working consumer needs it. Planned responsibilities are the cxx-qt app runtime, theme-state input, external process integration where required, and service catalog clients.

No runtime or client crates exist yet. Shared crates must not import Files or Pyxamp. Preserve licenses and tests when extracting existing code.
