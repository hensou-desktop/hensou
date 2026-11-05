//! Desktop provider embedded by Files. The shell draws; this crate owns actions and placement.
mod catalog;
mod positions;
use hensou_desktop_protocol::*;
use hensou_files_model::{
    Command, DeleteKind, Event, FilesError, FilesService, IconHint, Location, Place, TransferMode,
    platform::{IconResolver, ResolvedIcon, ThemeId, TrashStore, VolumeMonitor},
};
use notify::Watcher;
use positions::{GRID, Positions};
use std::{
    collections::HashMap,
    io::{self, BufReader},
    os::unix::{
        fs::MetadataExt,
        net::{UnixListener, UnixStream},
    },
    path::{Path, PathBuf},
    sync::{
        Arc, Mutex, Weak,
        atomic::{AtomicBool, AtomicU64, Ordering},
    },
    time::Duration,
};

#[derive(Clone, Debug)]
pub struct Config {
    pub desktop_dir: PathBuf,
    pub positions_file: PathBuf,
    pub hostname: String,
}
impl Config {
    pub fn from_env() -> io::Result<Self> {
        let home =
            PathBuf::from(std::env::var_os("HOME").ok_or_else(|| io::Error::other("HOME unset"))?);
        let config = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".config"));
        let desktop_dir = std::fs::read_to_string(config.join("user-dirs.dirs"))
            .ok()
            .and_then(|text| {
                text.lines().find_map(|l| {
                    l.trim().strip_prefix("XDG_DESKTOP_DIR=").map(|value| {
                        PathBuf::from(
                            value
                                .trim()
                                .trim_matches('"')
                                .replace("$HOME", &home.to_string_lossy()),
                        )
                    })
                })
            })
            .filter(|p| p.is_absolute())
            .unwrap_or_else(|| home.join("Desktop"));
        let state = std::env::var_os("XDG_STATE_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/state"));
        Ok(Self {
            desktop_dir,
            positions_file: state.join("hensou/desktop-positions.json"),
            hostname: std::fs::read_to_string("/proc/sys/kernel/hostname")?
                .trim()
                .into(),
        })
    }
}
struct Session {
    out: Mutex<UnixStream>,
    subscription: Mutex<Option<(Theme, ScreenLayout, Vec<DesktopIcon>)>>,
}
type PendingActions = HashMap<u64, (Weak<Session>, Vec<String>)>;

pub struct DesktopProvider {
    service: Arc<dyn FilesService>,
    trash: Arc<dyn TrashStore>,
    volumes: Arc<dyn VolumeMonitor>,
    icons: Arc<dyn IconResolver>,
    config: Config,
    positions: Mutex<Positions>,
    sessions: Mutex<Vec<Weak<Session>>>,
    next_request: AtomicU64,
    pending: Mutex<PendingActions>,
}
pub struct ProviderHandle {
    stop: Arc<AtomicBool>,
    thread: Option<std::thread::JoinHandle<()>>,
    path: PathBuf,
}
impl Drop for ProviderHandle {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
        let _ = std::fs::remove_file(&self.path);
    }
}
impl DesktopProvider {
    pub fn new(
        service: Arc<dyn FilesService>,
        trash: Arc<dyn TrashStore>,
        volumes: Arc<dyn VolumeMonitor>,
        icons: Arc<dyn IconResolver>,
        config: Config,
    ) -> io::Result<Self> {
        std::fs::create_dir_all(&config.desktop_dir)?;
        let positions = Positions::load(&config.positions_file)?;
        Ok(Self {
            service,
            trash,
            volumes,
            icons,
            config,
            positions: Mutex::new(positions),
            sessions: Mutex::new(Vec::new()),
            next_request: AtomicU64::new(1 << 48),
            pending: Mutex::new(HashMap::new()),
        })
    }
    /// Binds before returning; dropping the handle stops accepting clients.
    pub fn serve(self, path: impl AsRef<Path>) -> io::Result<ProviderHandle> {
        let path = path.as_ref().to_path_buf();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        // Never unlink an existing endpoint: another resident may own it.
        let listener = UnixListener::bind(&path)?;
        listener.set_nonblocking(true)?;
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600))?;
        let provider = Arc::new(self);
        let weak = Arc::downgrade(&provider);
        provider.service.subscribe(Box::new(move |event| {
            if let Some(provider) = weak.upgrade() {
                provider.service_event(event);
            }
        }));
        let weak = Arc::downgrade(&provider);
        provider.trash.watch(Box::new(move || {
            if let Some(provider) = weak.upgrade() {
                provider.refresh();
            }
        }));
        let weak = Arc::downgrade(&provider);
        provider.volumes.watch(Box::new(move |_| {
            if let Some(provider) = weak.upgrade() {
                provider.refresh();
            }
        }));
        let weak = Arc::downgrade(&provider);
        let mut watcher =
            notify::recommended_watcher(move |event: notify::Result<notify::Event>| {
                if event.is_ok_and(|event| !matches!(event.kind, notify::EventKind::Access(_)))
                    && let Some(provider) = weak.upgrade() {
                    provider.refresh();
                }
            })
            .map_err(io::Error::other)?;
        watcher
            .watch(
                &provider.config.desktop_dir,
                notify::RecursiveMode::NonRecursive,
            )
            .map_err(io::Error::other)?;
        let stop = Arc::new(AtomicBool::new(false));
        let stopping = stop.clone();
        let thread = std::thread::spawn(move || {
            let _watcher = watcher;
            while !stopping.load(Ordering::Relaxed) {
                match listener.accept() {
                    Ok((stream, _)) => {
                        let provider = provider.clone();
                        std::thread::spawn(move || {
                            let _ = provider.client(stream);
                        });
                    }
                    Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
                        std::thread::sleep(Duration::from_millis(20))
                    }
                    Err(_) => break,
                }
            }
            for session in provider.sessions.lock().unwrap().iter().filter_map(Weak::upgrade) {
                let _ = session.out.lock().unwrap().shutdown(std::net::Shutdown::Both);
            }
        });
        Ok(ProviderHandle {
            stop,
            thread: Some(thread),
            path,
        })
    }
    fn client(self: Arc<Self>, stream: UnixStream) -> io::Result<()> {
        stream.set_write_timeout(Some(Duration::from_secs(2)))?;
        let session = Arc::new(Session {
            out: Mutex::new(stream.try_clone()?),
            subscription: Mutex::new(None),
        });
        let mut input = BufReader::new(stream);
        match read_line::<ShellMessage>(&mut input)? {
            Some(ShellMessage::Hello { major, .. }) if compatible(major) => send(
                &session,
                &ProviderMessage::Hello {
                    major: PROTOCOL_MAJOR,
                    minor: PROTOCOL_MINOR,
                },
            )?,
            _ => {
                send(
                    &session,
                    &ProviderMessage::Error {
                        code: "version".into(),
                        message: "A compatible Hello must be the first message".into(),
                        ids: vec![],
                    },
                )?;
                return Ok(());
            }
        }
        self.sessions.lock().unwrap().push(Arc::downgrade(&session));
        while let Some(message) = read_line::<ShellMessage>(&mut input)? {
            if let Err(error) = self.action(&session, message) {
                send(&session, &protocol_error(error, vec![]))?;
            }
        }
        self.pending
            .lock()
            .unwrap()
            .retain(|_, (s, _)| !s.ptr_eq(&Arc::downgrade(&session)));
        Ok(())
    }
    fn snapshot(
        &self,
        theme: Theme,
        screen: &ScreenLayout,
    ) -> Result<Vec<DesktopIcon>, FilesError> {
        if !screen.scale.is_finite()
            || screen.scale <= 0.0
            || screen.usable.width == 0
            || screen.usable.height == 0
            || screen.usable.width > 32768
            || screen.usable.height > 32768
            || i64::from(screen.usable.x) + i64::from(screen.usable.width) > i64::from(i32::MAX)
            || i64::from(screen.usable.y) + i64::from(screen.usable.height) > i64::from(i32::MAX)
        {
            return Err(other("invalid screen layout"));
        }
        let mut icons = self
            .catalog(theme)?
            .into_iter()
            .map(|i| i.icon)
            .collect::<Vec<_>>();
        let mut positions = self.positions.lock().unwrap();
        positions.place(screen, &mut icons);
        positions
            .save(&self.config.positions_file)
            .map_err(io_error)?;
        Ok(icons)
    }
    fn refresh(&self) {
        let sessions = {
            let mut sessions = self.sessions.lock().unwrap();
            sessions.retain(|s| s.strong_count() > 0);
            sessions
                .iter()
                .filter_map(Weak::upgrade)
                .collect::<Vec<_>>()
        };
        for session in sessions {
            let mut subscription = session.subscription.lock().unwrap();
            if let Some((theme, screen, previous)) = subscription.as_mut() {
                match self.snapshot(*theme, screen) {
                    Ok(icons) => {
                        let upsert = icons
                            .iter()
                            .filter(|i| !previous.contains(i))
                            .cloned()
                            .collect::<Vec<_>>();
                        let removed = previous
                            .iter()
                            .filter(|old| !icons.iter().any(|i| i.id == old.id))
                            .map(|i| i.id.clone())
                            .collect::<Vec<_>>();
                        *previous = icons;
                        if !upsert.is_empty() || !removed.is_empty() {
                            let _ = send(&session, &ProviderMessage::Changed { upsert, removed });
                        }
                    }
                    Err(error) => {
                        let _ = send(&session, &protocol_error(error, vec![]));
                    }
                }
            }
        }
    }
    fn service_event(&self, event: Event) {
        match event {
            Event::Error {
                request: Some(request),
                error,
            } => {
                if let Some((session, ids)) = self.pending.lock().unwrap().remove(&request)
                    && let Some(session) = session.upgrade() {
                    let _ = send(&session, &protocol_error(error, ids));
                }
            }
            Event::Done { request } => {
                self.pending.lock().unwrap().remove(&request);
                self.refresh();
            }
            Event::Transfer { transfer } => {
                if matches!(
                    transfer.state,
                    hensou_files_model::TransferState::Done
                        | hensou_files_model::TransferState::Cancelled
                        | hensou_files_model::TransferState::Failed { .. }
                ) {
                    let pending = self.pending.lock().unwrap().remove(&transfer.id);
                    if let hensou_files_model::TransferState::Failed { reason } = &transfer.state
                        && let Some((session, ids)) = pending
                        && let Some(session) = session.upgrade() {
                        let _ = send(&session, &protocol_error(other(reason), ids));
                    }
                    self.refresh();
                }
            }
            Event::FolderChanged { .. } | Event::Trash { .. } | Event::Volumes { .. } => {
                self.refresh()
            }
            _ => {}
        }
    }
    fn command(&self, session: &Arc<Session>, ids: Vec<String>, command: Command) {
        let request = self.next_request.fetch_add(1, Ordering::Relaxed);
        self.pending
            .lock()
            .unwrap()
            .insert(request, (Arc::downgrade(session), ids));
        self.service.send(request, command);
    }
    fn action(&self, session: &Arc<Session>, message: ShellMessage) -> Result<(), FilesError> {
        if let ShellMessage::Subscribe { theme, screen } = message {
            let icons = self.snapshot(theme, &screen)?;
            let snap = self.positions.lock().unwrap().snap;
            let mut subscription = session.subscription.lock().unwrap();
            *subscription = Some((theme, screen, icons.clone()));
            return send(
                session,
                &ProviderMessage::Snapshot {
                    icons,
                    snap,
                    grid: GRID,
                },
            )
            .map_err(io_error);
        }
        let (theme, screen, mut icons) = session
            .subscription
            .lock()
            .unwrap()
            .clone()
            .ok_or_else(|| other("Subscribe before actions"))?;
        let catalog = self.catalog(theme)?;
        let select = |ids: &[String], files_only: bool| -> Result<Vec<Location>, FilesError> {
            ids.iter()
                .map(|id| {
                    let item = catalog
                        .iter()
                        .find(|i| &i.icon.id == id)
                        .ok_or(FilesError::NotFound)?;
                    if files_only && !id.starts_with("file:") {
                        return Err(FilesError::PermissionDenied);
                    }
                    Ok(item.location.clone())
                })
                .collect()
        };
        match message {
            ShellMessage::Open { ids } => {
                for location in select(&ids, false)? {
                    self.command(session, ids.clone(), Command::Open { location });
                }
            }
            ShellMessage::Rename { id, name } => {
                if name.is_empty()
                    || name == "."
                    || name == ".."
                    || name.contains('/')
                    || name.contains('\0')
                {
                    return Err(other("invalid file name"));
                }
                let locations = select(std::slice::from_ref(&id), true)?;
                self.command(
                    session,
                    vec![id],
                    Command::Rename {
                        location: locations[0].clone(),
                        new_name: name,
                    },
                );
            }
            ShellMessage::CheckTrash { request, ids } => {
                let locations = select(&ids, true)?;
                let permanent =
                    locations
                        .iter()
                        .find_map(|l| match self.trash.delete_kind(&l.path) {
                            DeleteKind::Permanent { reason } => Some(reason),
                            _ => None,
                        });
                let count = locations.len() as u32;
                let confirmation = if let Some(reason) = permanent {
                    Confirmation::Permanent { count, reason }
                } else {
                    Confirmation::MoveToTrash { count }
                };
                send(
                    session,
                    &ProviderMessage::ConfirmNeeded {
                        request,
                        ids,
                        confirmation,
                    },
                )
                .map_err(io_error)?;
            }
            ShellMessage::CheckEmptyTrash { request } => {
                let count = self.trash.items()?.len() as u32;
                send(
                    session,
                    &ProviderMessage::ConfirmNeeded {
                        request,
                        ids: vec!["trash".into()],
                        confirmation: Confirmation::EmptyTrash { count },
                    },
                )
                .map_err(io_error)?;
            }
            ShellMessage::Trash { ids } => {
                let locations = select(&ids, true)?;
                self.command(session, ids, Command::MoveToTrash { locations });
            }
            ShellMessage::DeletePermanently { ids } => {
                let locations = select(&ids, true)?;
                self.command(session, ids, Command::DeletePermanently { locations });
            }
            ShellMessage::EmptyTrash => {
                self.command(session, vec!["trash".into()], Command::EmptyTrash)
            }
            ShellMessage::Drop { ids, target } => {
                let sources = select(&ids, true)?;
                if target == "trash" {
                    self.command(session, ids, Command::MoveToTrash { locations: sources });
                } else {
                    let item = catalog
                        .iter()
                        .find(|i| i.icon.id == target)
                        .ok_or(FilesError::NotFound)?;
                    if !matches!(item.icon.kind, IconKind::Folder | IconKind::Volume) {
                        return Err(other("drop target is not a folder or volume"));
                    }
                    let target_dev = std::fs::metadata(&item.location.path)
                        .map_err(io_error)?
                        .dev();
                    let same = sources.iter().all(|s| {
                        std::fs::symlink_metadata(&s.path).is_ok_and(|m| m.dev() == target_dev)
                    });
                    self.command(
                        session,
                        ids,
                        Command::Transfer {
                            mode: if same {
                                TransferMode::Move
                            } else {
                                TransferMode::Copy
                            },
                            sources,
                            destination: item.location.clone(),
                        },
                    );
                }
            }
            ShellMessage::Eject { id } => {
                let volume = id.strip_prefix("volume:").ok_or(FilesError::NotFound)?;
                if let Err(error) = self.volumes.eject(volume) {
                    send(session, &protocol_error(error, vec![id])).map_err(io_error)?;
                } else {
                    self.refresh();
                }
            }
            ShellMessage::SetSnap { snap } => {
                {
                    let mut positions = self.positions.lock().unwrap();
                    positions.snap = snap;
                    positions
                        .save(&self.config.positions_file)
                        .map_err(io_error)?;
                }
                for session in self
                    .sessions
                    .lock()
                    .unwrap()
                    .iter()
                    .filter_map(Weak::upgrade)
                {
                    let _ = send(&session, &ProviderMessage::Snap { snap });
                }
            }
            ShellMessage::Move { moves } => {
                let snap = self.positions.lock().unwrap().snap;
                let cells = positions::cells(&screen);
                for (id, requested) in moves {
                    let used = icons
                        .iter()
                        .filter(|i| i.id != id)
                        .map(|i| i.position)
                        .collect::<Vec<_>>();
                    let icon = icons
                        .iter_mut()
                        .find(|i| i.id == id)
                        .ok_or(FilesError::NotFound)?;
                    icon.position = if snap || !positions::inside(&screen, requested) {
                        positions::nearest(&cells, &used, requested, &screen)
                    } else {
                        requested
                    };
                }
                self.save_icons(&screen, &icons)?;
                self.refresh();
            }
            ShellMessage::Arrange { by } => {
                match by {
                    ArrangeBy::Name => icons.sort_by_key(|i| i.label.to_lowercase()),
                    ArrangeBy::Kind => {
                        icons.sort_by_key(|i| (format!("{:?}", i.kind), i.label.to_lowercase()))
                    }
                    ArrangeBy::Size => icons.sort_by_key(|i| {
                        catalog
                            .iter()
                            .find(|v| v.icon.id == i.id)
                            .and_then(|v| v.size)
                    }),
                    ArrangeBy::Date => icons.sort_by_key(|i| {
                        catalog
                            .iter()
                            .find(|v| v.icon.id == i.id)
                            .and_then(|v| v.date)
                    }),
                    ArrangeBy::CleanUp => {}
                }
                let cells = positions::cells(&screen);
                let mut used = Vec::new();
                for icon in &mut icons {
                    icon.position = if by == ArrangeBy::CleanUp {
                        positions::nearest(&cells, &used, icon.position, &screen)
                    } else {
                        positions::first(&cells, &used, &screen)
                    };
                    used.push(icon.position);
                }
                self.save_icons(&screen, &icons)?;
                self.refresh();
            }
            ShellMessage::Hello { .. } => return Err(other("Hello was already received")),
            ShellMessage::Subscribe { .. } => unreachable!(),
        }
        Ok(())
    }
    fn save_icons(&self, screen: &ScreenLayout, icons: &[DesktopIcon]) -> Result<(), FilesError> {
        let mut positions = self.positions.lock().unwrap();
        positions.update(screen, icons);
        positions
            .save(&self.config.positions_file)
            .map_err(io_error)
    }
}
fn send(session: &Session, message: &ProviderMessage) -> io::Result<()> {
    write_line(&mut *session.out.lock().unwrap(), message)
}
fn other(message: impl Into<String>) -> FilesError {
    FilesError::Other {
        message: message.into(),
    }
}
fn io_error(error: io::Error) -> FilesError {
    match error.kind() {
        io::ErrorKind::NotFound => FilesError::NotFound,
        io::ErrorKind::PermissionDenied => FilesError::PermissionDenied,
        io::ErrorKind::AlreadyExists => FilesError::AlreadyExists,
        _ => other(error.to_string()),
    }
}
fn protocol_error(error: FilesError, ids: Vec<String>) -> ProviderMessage {
    let code = match error {
        FilesError::NotFound => "not-found",
        FilesError::PermissionDenied => "permission",
        FilesError::AlreadyExists => "exists",
        FilesError::VolumeBusy { .. } => "busy",
        _ => "other",
    };
    ProviderMessage::Error {
        code: code.into(),
        message: format!("{error:?}"),
        ids,
    }
}
