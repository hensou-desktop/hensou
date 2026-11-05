//! The boundary between the Files user interface, its backend and the desktop
//! provider. Hosts send [`Command`]s and receive [`Event`]s; nothing here does
//! I/O. Implementations: `hensou-files-core` (real) and [`fake`] (fixtures).
//!
//! Language follows `CONTEXT.md`: place, SSH host, transfer, working copy,
//! alias, volume, Trash.

pub mod fake;
pub mod platform;

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Correlates a command with the events it causes. Chosen by the caller.
pub type RequestId = u64;

/// Where a location lives.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub enum Place {
    /// The Computer window: Home, volumes, SSH Hosts and the Trash.
    Computer,
    /// The local machine's filesystem.
    Local,
    /// The SSH Hosts folder: the concrete `Host` entries in `~/.ssh/config`.
    SshHosts,
    /// One named SSH host from `~/.ssh/config`.
    Host { name: String },
    /// The merged Trash: home Trash plus each volume's and host's own.
    Trash,
}

/// A folder or file inside a place. `path` is absolute for `Local` and `Host`
/// and empty for the virtual places.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Location {
    pub place: Place,
    pub path: PathBuf,
}

impl Location {
    pub fn local(path: impl Into<PathBuf>) -> Self {
        Self {
            place: Place::Local,
            path: path.into(),
        }
    }
    pub fn host(name: impl Into<String>, path: impl Into<PathBuf>) -> Self {
        Self {
            place: Place::Host { name: name.into() },
            path: path.into(),
        }
    }
    pub fn virtual_place(place: Place) -> Self {
        Self {
            place,
            path: PathBuf::new(),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum EntryKind {
    Folder,
    File,
    /// A symbolic link: shown as an alias (Platinum) or shortcut (Memphis).
    Alias,
    /// A `.desktop` launcher.
    Launcher,
    Computer,
    Volume,
    SshHosts,
    Host,
    Trash,
}

/// The theme-independent icon request for an entry. Hosts resolve it with
/// [`platform::IconResolver`]; never with Adwaita or hicolor art.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct IconHint {
    /// A freedesktop MIME type or icon name, such as `text-plain` or `folder`.
    pub name: String,
    /// The launcher's own icon name, for lettermark decisions.
    pub launcher_icon: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Entry {
    pub location: Location,
    pub name: String,
    pub kind: EntryKind,
    /// `None` displays as unknown, never as zero.
    pub size: Option<u64>,
    /// Seconds since the Unix epoch.
    pub modified: Option<i64>,
    pub hidden: bool,
    /// The target of an alias, as stored in the link.
    pub link_target: Option<PathBuf>,
    pub owner: Option<String>,
    /// Unix mode bits. Locked/Read-only map to the write bits.
    pub mode: Option<u32>,
    pub icon: IconHint,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "state", rename_all = "kebab-case")]
pub enum ConnectionState {
    Connected,
    Connecting,
    /// Windows keep the last listing, greyed, marked "Reconnecting…".
    Reconnecting { since: i64, attempt: u32 },
    /// Idle connections close after 10 minutes; the next action reconnects.
    Idle,
    Failed { reason: String },
    /// A changed key is never trusted; this stops reconnecting.
    HostKeyChanged { fingerprint: String },
}

/// An unknown host key awaiting explicit trust. Cancel is the default.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostKeyPrompt {
    pub host: String,
    pub algorithm: String,
    /// `SHA256:...` as `ssh-keygen -l` prints it.
    pub fingerprint: String,
}

pub type TransferId = u64;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum TransferMode {
    Copy,
    Move,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "state", rename_all = "kebab-case")]
pub enum TransferState {
    Queued,
    Running,
    /// A dropped link: waits, then continues from its byte offset.
    WaitingForHost { host: String, since: i64 },
    /// After 10 minutes offline the user chooses: keep waiting or cancel.
    AskKeepWaiting { host: String },
    Conflict { conflict: Conflict },
    Done,
    Failed { reason: String },
    Cancelled,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Conflict {
    pub source: Entry,
    pub existing: Entry,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ConflictChoice {
    Replace,
    Skip,
    KeepBoth,
    Stop,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Transfer {
    pub id: TransferId,
    pub mode: TransferMode,
    pub sources: Vec<Location>,
    pub destination: Location,
    pub current: Option<Location>,
    pub items_done: u64,
    pub items_total: Option<u64>,
    pub bytes_done: u64,
    pub bytes_total: Option<u64>,
    pub state: TransferState,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "state", rename_all = "kebab-case")]
pub enum WorkingCopyState {
    Watching,
    Uploading,
    /// Saved while the host was offline; uploads after the reconnect.
    UploadQueued,
    /// The host's copy changed since it was opened: needs a choice.
    RemoteChanged,
    Failed { reason: String },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkingCopy {
    pub remote: Location,
    pub local: PathBuf,
    pub last_saved: Option<i64>,
    pub state: WorkingCopyState,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum RemoteChangeChoice {
    Overwrite,
    KeepRemote,
    SaveAsCopy,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ViewKind {
    Icons,
    List,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Geometry {
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
}

/// Remembered per folder, in both themes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ViewMemory {
    pub geometry: Option<Geometry>,
    pub view: ViewKind,
    pub sort_column: String,
    pub sort_ascending: bool,
    pub show_hidden: bool,
}

impl Default for ViewMemory {
    fn default() -> Self {
        Self {
            geometry: None,
            view: ViewKind::Icons,
            sort_column: "name".into(),
            sort_ascending: true,
            show_hidden: false,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Volume {
    /// Stable id, such as the udisks2 block object path.
    pub id: String,
    pub label: String,
    pub mount_point: Option<PathBuf>,
    pub removable: bool,
    pub size: Option<u64>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TrashItem {
    /// Where the item came from.
    pub original: Location,
    /// Where it waits now.
    pub stored: Location,
    pub deleted_at: Option<i64>,
    pub entry: Entry,
}

/// Whether a delete at a location can be undone.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub enum DeleteKind {
    /// Moves to a Trash; reversible.
    Trash,
    /// No Trash on that filesystem: say so before acting.
    Permanent { reason: String },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "command", rename_all = "kebab-case")]
pub enum Command {
    List { location: Location },
    /// Folders open a Files window; files use the default desktop handler;
    /// remote files open as a working copy.
    Open { location: Location },
    OpenWith { location: Location, desktop_id: String },
    ListHandlers { location: Location },
    Info { location: Location },
    Rename { location: Location, new_name: String },
    NewFolder { parent: Location, name: String },
    Transfer { mode: TransferMode, sources: Vec<Location>, destination: Location },
    CancelTransfer { id: TransferId },
    ResolveConflict { id: TransferId, choice: ConflictChoice, apply_to_all: bool },
    KeepWaiting { id: TransferId, keep: bool },
    /// Reports per location whether deletion would be permanent.
    CheckDelete { locations: Vec<Location> },
    MoveToTrash { locations: Vec<Location> },
    DeletePermanently { locations: Vec<Location> },
    RestoreFromTrash { items: Vec<Location> },
    EmptyTrash,
    TrustHostKey { host: String, fingerprint: String },
    RejectHostKey { host: String },
    Connect { host: String },
    ResolveRemoteChange { remote: Location, choice: RemoteChangeChoice },
    StopWatching { remote: Location },
    Eject { volume_id: String },
    LoadView { location: Location },
    SaveView { location: Location, view: ViewMemory },
    /// Downloads a remote file for drag/clipboard; the path arrives in
    /// [`Event::Prepared`]. Local locations resolve at once.
    Prepare { locations: Vec<Location> },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "kebab-case")]
pub enum Event {
    Listing { request: RequestId, location: Location, entries: Vec<Entry> },
    /// A watched folder changed; hosts re-list or apply the new entries.
    FolderChanged { location: Location, entries: Vec<Entry> },
    Info { request: RequestId, entry: Entry },
    Handlers { request: RequestId, location: Location, handlers: Vec<Handler> },
    Connection { host: String, state: ConnectionState },
    HostKey { prompt: HostKeyPrompt },
    Hosts { names: Vec<String> },
    Transfer { transfer: Transfer },
    WorkingCopy { copy: WorkingCopy },
    WorkingCopyRemoved { remote: Location },
    DeleteCheck { request: RequestId, results: Vec<(Location, DeleteKind)> },
    Volumes { volumes: Vec<Volume> },
    Trash { items: Vec<TrashItem> },
    View { request: RequestId, location: Location, view: ViewMemory },
    Prepared { request: RequestId, paths: Vec<PathBuf> },
    /// The command finished without a more specific event.
    Done { request: RequestId },
    Error { request: Option<RequestId>, error: FilesError },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Handler {
    pub desktop_id: String,
    pub name: String,
    pub icon: Option<String>,
    pub is_default: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "kebab-case")]
pub enum FilesError {
    NotFound,
    PermissionDenied,
    AlreadyExists,
    VolumeBusy { holders: Vec<String> },
    HostUnreachable { host: String },
    HostKeyRejected { host: String },
    Unsupported { what: String },
    Other { message: String },
}

pub type EventSink = Box<dyn Fn(Event) + Send + Sync>;

/// Files' service. Implementations run their own threads or runtime; `send`
/// never blocks on I/O. Events may arrive on any thread; hosts marshal them
/// to their UI thread.
pub trait FilesService: Send + Sync {
    fn send(&self, request: RequestId, command: Command);
    /// Every subscriber receives every event from the moment it subscribes.
    /// On subscribe the service sends its current hosts, volumes, Trash,
    /// transfers and working copies.
    fn subscribe(&self, sink: EventSink);
}
