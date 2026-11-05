//! The shell–Files desktop icon protocol (ADR 0006).
//!
//! Transport: a Unix stream socket at `$XDG_RUNTIME_DIR/hensou/desktop.sock`,
//! one JSON object per line (UTF-8, `\n`-terminated), both directions.
//!
//! Session: the shell sends [`ShellMessage::Hello`] first. The provider replies
//! [`ProviderMessage::Hello`] with its version; on a major mismatch it sends
//! [`ProviderMessage::Error`] with `code = "version"` and closes. Then the
//! shell sends `Subscribe` with the primary screen's layout and receives a
//! full `Snapshot`, followed by `Changed` deltas. A new `Subscribe` (after a
//! display change) gets a fresh snapshot with recovered positions.
//!
//! The provider owns positions, Snap to Grid and arrangement. The shell only
//! sends user intents and draws what it receives. Labels are theme-specific
//! (`My Computer` vs the host name), so the shell names its theme on subscribe.

use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, Write};
use std::path::PathBuf;

pub const PROTOCOL_MAJOR: u32 = 1;
pub const PROTOCOL_MINOR: u32 = 0;

/// `$XDG_RUNTIME_DIR/hensou/desktop.sock`.
pub fn socket_path() -> Option<PathBuf> {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(|d| PathBuf::from(d).join("hensou").join("desktop.sock"))
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Theme {
    Platinum,
    /// Persisted as `memphis`.
    #[serde(rename = "memphis")]
    Memphis,
}

/// The primary screen in logical pixels, minus reserved bars.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ScreenLayout {
    /// Output name, such as `DP-1`.
    pub output: String,
    pub width: u32,
    pub height: u32,
    pub scale: f64,
    /// Area icons may occupy (excludes the top bar or taskbar).
    pub usable: Rect,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Rect {
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Point {
    pub x: i32,
    pub y: i32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum IconKind {
    File,
    Folder,
    Alias,
    Launcher,
    Computer,
    Volume,
    SshHosts,
    Libraries,
    Trash,
}

/// How the shell draws an icon. `themed` and `generic` are paths inside the
/// active theme's art; `lettermark` asks for a period letter tile.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub enum IconArt {
    Themed { path: PathBuf },
    Generic { kind: String, path: PathBuf },
    Lettermark { letter: char, tint: String },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DesktopIcon {
    /// Stable across restarts: `file:<name>`, `computer`, `volume:<id>`,
    /// `ssh-hosts`, `trash`.
    pub id: String,
    pub kind: IconKind,
    pub label: String,
    pub art: IconArt,
    /// Top-left in logical pixels inside `usable`.
    pub position: Point,
    /// False greys the icon and `reason` explains why.
    pub available: bool,
    pub reason: Option<String>,
    /// Trash only: whether it holds items (full vs empty art).
    pub full: Option<bool>,
    /// Volume only.
    pub ejectable: Option<bool>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ArrangeBy {
    /// Platinum Clean Up: snap each icon to its nearest free grid cell.
    CleanUp,
    Name,
    Kind,
    Size,
    Date,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub enum ShellMessage {
    Hello {
        major: u32,
        minor: u32,
    },
    Subscribe {
        theme: Theme,
        screen: ScreenLayout,
    },
    Open {
        ids: Vec<String>,
    },
    /// The user dropped icons at new positions.
    Move {
        moves: Vec<(String, Point)>,
    },
    /// Icons dropped onto a target icon (Trash, folder, volume).
    Drop {
        ids: Vec<String>,
        target: String,
    },
    Rename {
        id: String,
        name: String,
    },
    /// Ask what deleting would do; the provider answers `ConfirmNeeded`.
    CheckTrash {
        request: u64,
        ids: Vec<String>,
    },
    /// Sent after the shell's confirmation, when one was needed.
    Trash {
        ids: Vec<String>,
    },
    DeletePermanently {
        ids: Vec<String>,
    },
    CheckEmptyTrash {
        request: u64,
    },
    EmptyTrash,
    Eject {
        id: String,
    },
    Arrange {
        by: ArrangeBy,
    },
    SetSnap {
        snap: bool,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub enum Confirmation {
    /// Reversible: Platinum moves at once, Memphis asks first.
    MoveToTrash { count: u32 },
    /// No Trash can take these: both themes warn before acting.
    Permanent { count: u32, reason: String },
    /// Always asks; Cancel / No is the default.
    EmptyTrash { count: u32 },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub enum ProviderMessage {
    Hello {
        major: u32,
        minor: u32,
    },
    Snapshot {
        icons: Vec<DesktopIcon>,
        snap: bool,
        grid: GridSpec,
    },
    /// Upserts by id, then removals.
    Changed {
        upsert: Vec<DesktopIcon>,
        removed: Vec<String>,
    },
    Snap {
        snap: bool,
    },
    ConfirmNeeded {
        request: u64,
        ids: Vec<String>,
        confirmation: Confirmation,
    },
    /// A failed action, shown as a themed alert. `code` is stable:
    /// `version`, `busy`, `not-found`, `permission`, `exists`, `other`.
    Error {
        code: String,
        message: String,
        ids: Vec<String>,
    },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GridSpec {
    pub cell_width: u32,
    pub cell_height: u32,
}

/// Writes one message as one line.
pub fn write_line<T: Serialize>(out: &mut impl Write, message: &T) -> io::Result<()> {
    let mut line = serde_json::to_vec(message).map_err(io::Error::other)?;
    line.push(b'\n');
    out.write_all(&line)?;
    out.flush()
}

/// Reads one message; `Ok(None)` at end of stream.
pub fn read_line<T: for<'de> Deserialize<'de>>(input: &mut impl BufRead) -> io::Result<Option<T>> {
    let mut line = String::new();
    if input.read_line(&mut line)? == 0 {
        return Ok(None);
    }
    serde_json::from_str(line.trim_end())
        .map(Some)
        .map_err(io::Error::other)
}

/// True when a peer speaking `major` can talk to this version.
pub fn compatible(major: u32) -> bool {
    major == PROTOCOL_MAJOR
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn messages_round_trip_as_lines() {
        let message = ShellMessage::Move {
            moves: vec![("trash".into(), Point { x: 10, y: 20 })],
        };
        let mut buf = Vec::new();
        write_line(&mut buf, &message).unwrap();
        assert_eq!(buf.iter().filter(|b| **b == b'\n').count(), 1);
        let back: ShellMessage = read_line(&mut buf.as_slice()).unwrap().unwrap();
        assert_eq!(back, message);
    }

    #[test]
    fn memphis_is_persisted_as_memphis() {
        assert_eq!(serde_json::to_string(&Theme::Memphis).unwrap(), "\"memphis\"");
    }

    #[test]
    fn other_major_versions_are_refused() {
        assert!(compatible(PROTOCOL_MAJOR));
        assert!(!compatible(PROTOCOL_MAJOR + 1));
    }
}
