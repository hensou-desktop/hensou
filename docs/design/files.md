# Files design

Files is the first new app after Pyxamp proves Hensou's kit. Its initial release covers local files and SSH hosts. The later libraries and desktop integration must fit the design but are not implemented by this scaffold.

## Themes and windows

Both themes expose the same capabilities. Platinum, the Mac-inspired theme, uses spatial folder windows. Memphis, the Windows-inspired theme, uses an Explorer-style tree. App menus stay inside the windows. Each folder remembers size, position, view and sorting. Hyprland integration is required for positions that Wayland clients cannot set themselves.

## Local and SSH files

Connect inside Files using normal SSH config, keys and agent. No prior mount and no password store. Unknown host keys require explicit trust with Cancel as the default. Failed or changed host identities must not be silently trusted.

Copy through the local machine between remote hosts. Transfers outlive their windows. Show progress, conflicts, failures and cancellation in both themes.

Open remote files through a local working copy. Upload after saves only after checking whether the remote copy changed. A detected conflict needs a choice before overwrite. Deletion uses the host's Trash when supported. If only permanent deletion is available, say so before acting. Do not describe a deletion as reversible without a proven Trash path.

## First-release decisions (2026-11-05)

- SSH: system OpenSSH ([ADR 0005](../decisions/0005-files-ssh-client.md)). The SSH Hosts list contains only the named hosts in `~/.ssh/config`. Files acts only as the SSH user, with no sudo mode.
- Phase 3 ships as one build and one deployment.
- Platinum windows follow Mac OS 8 faithfully. Double-click opens a folder in its own window. A folder that is already open comes to the front. Option-double-click closes the parent window. Cmd-Up opens the enclosing folder.
- Drags and the clipboard follow each theme's own OS. A drag on the same disk moves; a drag to another disk or host copies. Platinum: Option forces a copy. Memphis: Ctrl forces a copy, Shift forces a move, and a right-drag shows a menu. Memphis has Cut, Copy and Paste for files.
- Files trades files with other apps through drag-and-drop and the clipboard (`text/uri-list`), including remote files, which are downloaded when they are dropped or pasted.
- Opening a file uses the default desktop handler. Open With… lists the other apps that declare the type.
- A working copy lasts until the user stops watching it, or until 7 days pass without a save. Working copies are listed beside transfers. Files never deletes a working copy whose changes have not reached the host.
- Get Info / Properties shows name, kind, size, dates, owner and permissions. Only the name can be changed. Locked (Platinum) and Read-only (Memphis) map to the write bits.
- Hidden files are hidden by default. A View menu toggle is remembered per folder. Memphis calls it "Show all files".
- No thumbnails: folders show the theme's system icons.
- Transfers are not resumed. Copies write to a temporary name and rename at the end. After a quit or crash, Files removes the partial files and shows the transfer as failed.
- Symbolic links appear as aliases (Platinum, italic name) or shortcuts (Memphis, arrow overlay). Opening follows the link. Copying copies the link itself.

## Future libraries

Pyxis, Ossicle, Comics and Jellyfin appear as a separate group. Browse the service's own catalog sections, use per-kind columns and expose read/play state without writing it. Artwork comes from the API or generated previews, with system icons as fallback.

Libraries are read-only. Opening and copying use original bytes and desktop handlers, with a bounded cache where a local file is required. A handler accepting URLs does not automatically prove it accepts authenticated library URLs; validate that boundary. Unknown sizes display as unknown.

Credentials use the existing sops-managed secret-file arrangement. There is no new sign-in dialog. Comics needs an original-download endpoint before its items can open or copy.

## Future desktop icons

The shell draws Desktop folder contents, the local computer, a single SSH Hosts entry, libraries and Trash. Mounted volumes follow each theme's desktop convention. Files supplies data and actions. Users place icons freely, with arrange/cleanup and recovery after display changes.

See [desktop-icons.md](desktop-icons.md) for the Phase 5 design.

## Non-goals for the first build

No Android, search, new theme variants, library import/delete, or desktop icons. No migrations of the existing desktop happen until kit parity is proved.

The source interview is preserved in [the archive](../archive/files-interview.md). Later monorepo and stack decisions supersede its old repository plans and experimental claims. Temporary mock and benchmark paths in that archive are local evidence, not portable dependencies.
