# Desktop icons design

Phase 5 puts icons on the desktop in both themes. The shell draws them; Files supplies them and acts on them over a versioned local socket ([ADR 0005](../decisions/0005-desktop-icons.md)). Decisions below came from the owner interview on 2026-11-05.

## Which icons

| Icon | Platinum | Memphis |
| --- | --- | --- |
| Desktop folder entries | On the desktop | On the desktop |
| The local computer | On the desktop | My Computer |
| Volumes | One icon each on the desktop | Inside My Computer |
| SSH hosts | One SSH Hosts icon | Network Neighborhood |
| Libraries | One volume icon per library | One Libraries icon |
| Trash | Trash | Recycle Bin |

The computer icon is called My Computer in Memphis. In Platinum it carries the machine's name, for example Myoko. Icons appear on the primary screen only, and every workspace shows the same icons. Hidden entries in the desktop folder stay hidden. Libraries stay hidden until a library adapter exists (Phase 4); a library without its secret never appears. SSH Hosts shows now.

## Placement

Placement is free and remembered per screen layout. Clean Up (Platinum) and Arrange Icons (Memphis) tidy the icons. One shared Snap to Grid setting, off by default, appears in the desktop context menu of both themes. Icons that fall outside the screen after a display change come back into view.

## Interactions in the first release

- Open, move, rubber-band selection and keyboard navigation.
- Context menu: Open, Rename, Move to Trash, Empty Trash, Eject, Clean Up / Arrange Icons, Snap to Grid. Get Info / Properties waits for Files.
- Drop on the Trash, Empty Trash and Eject.
- Move to Trash follows each OS: Memphis asks first and Platinum does not. Both themes always warn before a permanent delete, for example on a volume with no Trash.
- Show Desktop uncovers the icons: Super+Shift+D, the Quick Launch button in Memphis, and Hide Others plus a desktop menu item in Platinum. The windows move to a hidden special workspace. Running Show Desktop again brings them back.
- Eject of a volume in use shows a themed alert, and the volume stays mounted.
- Empty Trash always asks, names the item count and makes Cancel / No the default button.

Not in this release: New Folder, drag between the desktop and app windows, cut/copy/paste.

## Opening

Files open with their normal desktop handler. Until Files has windows, folders, the computer, the Trash and volumes open with the current default folder handler; SSH Hosts shows a themed notice that Files is not installed yet. A temporary host runs the provider crate until Files' resident process embeds it.

## Volumes

Removable media mounts on insert through udisks2, under `/run/media/$USER`. Internal partitions that are not mounted stay hidden. Eject unmounts and then powers the device off.

## Icon art

Desktop icons never show Adwaita or hicolor art: that breaks the period look. A file uses its theme's exact icon when the theme's own set has one. Otherwise it gets the theme's generic icon for its kind: document, text, image, audio, video, archive, application or folder. An app launcher whose icon exists only in hicolor gets a period lettermark in the theme's style, as web apps do today.

The desktop folder is the XDG Desktop directory, `~/Desktop` by default, created when missing.
