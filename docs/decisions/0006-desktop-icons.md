# Files supplies desktop icons; the shell draws them

The shell draws desktop icons with the kit on its own desktop surface, so the icons stay drawn while Files restarts. Files supplies the icon list and performs every action (open, move, rename, trash, eject) over a versioned local socket. The provider is a Hensou crate that Files' resident process embeds. We rejected a separate always-on desktop service: it would duplicate Files' watching of volumes and the Trash for little gain.

Phases 3 and 5 ship together in one build and one deploy, so Files' resident process embeds the provider from the start; there is no interim host. The provider reuses the shared Trash, volume and file-kind icon crates that Files uses.

Icons appear on the primary screen only, in both themes. Placement is free and remembered per screen layout, with Clean Up / Arrange Icons, an optional snap-to-grid setting, and recovery of icons that fall outside the screen. Removable volumes mount on insert, as in both period systems.
