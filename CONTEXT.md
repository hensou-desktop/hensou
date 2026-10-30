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
The Windows-inspired theme. Its persisted identifier stays `win98`; user-visible text says Memphis. It has light and dark appearances.
_Avoid_: Windows 98, Win98 (in user-visible text)

**Theme parity**:
Every supported theme exposes the same capabilities and handles the same states. A difference needs an explicit reason.

**Place**:
A location Files can browse, such as a local folder, an SSH host or a library.

**SSH host**:
A machine Files connects to inside the app using the user's existing SSH identity. It does not require a prior filesystem mount.

**Library**:
A service-owned catalog presented as items and collections rather than storage paths. This differs from a server's media directory.

**Item**:
A catalog entry that the desktop can open or copy as a file when its service provides the original bytes.
