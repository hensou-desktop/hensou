# Shared Rust code

Create a crate only when a working consumer needs it. Shared responsibilities are Rust/Qt hosting, theme-state input and generic desktop integration required by real consumers.

No runtime crates exist yet. Shared crates must not import app-specific behavior. Media playback, authentication and service clients stay outside the generic kit. Preserve licenses and tests when extracting existing code.
