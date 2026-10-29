# Desktop essentials live here; independent products do not

Hensou owns the generic theme kit, Rust/Qt integration and desktop essentials such as Files and appearance settings. Independent products, including Pyxamp and Forgerie, stay in their own repositories and can consume pinned Hensou versions.

This supersedes the Pyxamp import and service-client extraction parts of earlier plans. Backend dependencies are a useful signal, but product ownership and release boundaries determine repository placement. Service-specific clients are not toolkit code merely because two apps could use them.

Phase 1 proves the kit with a standalone demo and the existing shell. Files does not wait for a Pyxamp migration. External apps require separate dependency updates, which is the cost of independent releases.
