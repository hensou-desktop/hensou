# Files design

Files is the first new app after Pyxamp proves Hensou's kit. Its initial release covers local files and SSH hosts. The later libraries and desktop integration must fit the design but are not implemented by this scaffold.

## Themes and windows

Both themes expose the same capabilities. The classic Mac-inspired presentation uses spatial folder windows; the Windows-inspired presentation uses an Explorer-style tree. App menus stay inside the windows. Each folder remembers size, position, view and sorting. Hyprland integration is required for positions that Wayland clients cannot set themselves.

## Local and SSH files

Connect inside Files using normal SSH config, keys and agent. No prior mount and no password store. Unknown host keys require explicit trust with Cancel as the default. Failed or changed host identities must not be silently trusted.

Copy through the local machine between remote hosts. Transfers outlive their windows. Show progress, conflicts, failures and cancellation in both themes.

Open remote files through a local working copy. Upload after saves only after checking whether the remote copy changed. A detected conflict needs a choice before overwrite. Deletion uses the host's Trash when supported. If only permanent deletion is available, say so before acting. Do not describe a deletion as reversible without a proven Trash path.

## Future libraries

Pyxis, Ossicle, Comics and Jellyfin appear as a separate group. Browse the service's own catalog sections, use per-kind columns and expose read/play state without writing it. Artwork comes from the API or generated previews, with system icons as fallback.

Libraries are read-only. Opening and copying use original bytes and desktop handlers, with a bounded cache where a local file is required. A handler accepting URLs does not automatically prove it accepts authenticated library URLs; validate that boundary. Unknown sizes display as unknown.

Credentials use the existing sops-managed secret-file arrangement. There is no new sign-in dialog. Comics needs an original-download endpoint before its items can open or copy.

## Future desktop icons

The shell draws Desktop folder contents, the local computer, a single SSH Hosts entry, libraries and Trash. Mounted volumes follow each theme's desktop convention. Files supplies data and actions. Users place icons freely, with arrange/cleanup and recovery after display changes.

## Non-goals for the first build

No Android, search, new theme variants, library import/delete, or desktop icons. No migrations of the existing desktop happen until kit parity is proved.

The source interview is preserved in [the archive](../archive/files-interview.md). Later monorepo and stack decisions supersede its old repository plans and experimental claims. Temporary mock and benchmark paths in that archive are local evidence, not portable dependencies.
