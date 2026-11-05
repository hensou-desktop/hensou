# Hensou desktop

Hensou keeps the desktop shell and the owner's apps visually consistent while they share behavior across themes.

## Language

**Hensou**:
The shared desktop kit and the app family built with it. The name comes from 変装, disguise.

**Theme**:
An appearance and interaction style for the same capabilities. A theme can change layout, controls and window conventions, not only colors.

**Platinum**:
The Mac-inspired theme. Its persisted identifier is `platinum`. It has light, dark and extra-dark appearances.

**Memphis**:
The Windows-inspired theme. Its persisted identifier is `memphis`. It has light and dark appearances.
_Avoid_: any Windows version name, in code or text

**Theme parity**:
Every supported theme exposes the same capabilities and handles the same states. A difference needs an explicit reason.

**Place**:
A location Files can browse, such as a local folder, an SSH host or a library.

**SSH host**:
A machine Files connects to inside the app using the user's existing SSH identity. It does not require a prior filesystem mount. The SSH hosts are exactly the named hosts in the user's SSH configuration.

**Computer window**:
The Files window for the local machine. It lists Home, the volumes, SSH Hosts and the Trash. Platinum titles it with the machine's name; Memphis calls it My Computer.

**Transfer**:
A copy or move that Files runs on behalf of the user. It belongs to Files, not to a window, and ends as done, failed or cancelled. An interrupted transfer is not resumed.

**Working copy**:
A local copy of a remote file that is opened in another app. Files sends each save back to the SSH host after checking that the host's copy has not changed.

**Alias**:
A symbolic link as Files shows it. Platinum calls it an alias and Memphis calls it a shortcut. Copying an alias copies the link, not its target.
_Avoid_: symlink (in user-visible text)

**Library**:
A service-owned catalog presented as items and collections rather than storage paths. This differs from a server's media directory.

**Item**:
A catalog entry that the desktop can open or copy as a file when its service provides the original bytes.

**Desktop**:
The primary screen's background, where the shell shows desktop icons. Other screens show the pattern only.

**Desktop icon**:
One thing shown on the desktop: an entry in the desktop folder, the local computer, a volume, the SSH Hosts entry, the libraries, or the Trash. The shell draws it; Files supplies it and acts on it.

**Desktop folder**:
The user's XDG Desktop directory, `~/Desktop` by default. Its entries appear as desktop icons.
_Avoid_: desktop (for the folder)

**Volume**:
A mounted disk or removable drive. Platinum shows each volume on the desktop; Memphis shows them inside My Computer.
_Avoid_: mount, drive (in user-visible text, each theme uses its own word)

**Trash**:
Where deleted local files wait until the user empties it. Memphis calls it the Recycle Bin.
