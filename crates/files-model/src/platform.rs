//! Interfaces of the shared platform crates. `hensou-trash`,
//! `hensou-volumes` and `hensou-file-icons` implement them; `files-core` and
//! the desktop provider consume them. Remote (SSH) Trash stays in files-core.

use crate::{DeleteKind, FilesError, TrashItem, Volume};
use std::path::{Path, PathBuf};

/// The local freedesktop Trash: the home Trash plus each mounted volume's
/// `.Trash-$uid` / `.Trash/$uid`.
pub trait TrashStore: Send + Sync {
    /// `Permanent` when no Trash on the same filesystem can take the path.
    fn delete_kind(&self, path: &Path) -> DeleteKind;
    /// Returns where the item now waits.
    fn trash(&self, path: &Path) -> Result<PathBuf, FilesError>;
    fn items(&self) -> Result<Vec<TrashItem>, FilesError>;
    fn restore(&self, stored: &Path) -> Result<PathBuf, FilesError>;
    fn empty(&self) -> Result<u64, FilesError>;
    /// Called after any Trash change, including changes made by other apps.
    fn watch(&self, on_change: Box<dyn Fn() + Send + Sync>);
}

/// Removable media through udisks2. Mounts on insert, removable media only;
/// internal partitions that are not mounted stay hidden.
pub trait VolumeMonitor: Send + Sync {
    fn volumes(&self) -> Vec<Volume>;
    /// Unmounts, then powers the drive off. A busy volume returns
    /// [`FilesError::VolumeBusy`] and stays mounted.
    fn eject(&self, volume_id: &str) -> Result<(), FilesError>;
    fn watch(&self, on_change: Box<dyn Fn(Vec<Volume>) + Send + Sync>);
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ThemeId {
    Platinum,
    Memphis,
}

impl ThemeId {
    /// The persisted theme name (`platinum` or `win98`).
    pub fn from_state(name: &str) -> Self {
        if name.trim() == "win98" {
            Self::Memphis
        } else {
            Self::Platinum
        }
    }
}

/// A generic kind used when the theme has no exact icon.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum GenericKind {
    Document,
    Text,
    Image,
    Audio,
    Video,
    Archive,
    Application,
    Folder,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ResolvedIcon {
    /// A file from the theme's own icon set.
    Themed(PathBuf),
    /// The theme's generic icon for a kind.
    Generic(GenericKind, PathBuf),
    /// A launcher whose icon exists only in hicolor: draw a period lettermark.
    Lettermark { letter: char, tint: String },
}

/// Resolves icons inside the theme's own set: exact, then generic kind, then
/// lettermark. It never returns Adwaita or hicolor art.
pub trait IconResolver: Send + Sync {
    fn resolve(&self, theme: ThemeId, hint: &crate::IconHint, size: u32) -> ResolvedIcon;
}
