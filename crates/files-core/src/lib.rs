//! Real Files service. Commands are queued; caller threads never perform I/O.
//!
//! A Transfer or Prepare request ID is also its transfer ID. Callers sharing a
//! service must allocate unique IDs while work is active. Duplicate active IDs
//! produce an Error and do not start another job. Prepare cancellation uses
//! CancelTransfer and never emits Prepared after cancellation.
mod local;
mod remote;
mod remote_trash;
mod transfer;
mod working;

use hensou_files_model::{
    platform::{TrashStore, VolumeMonitor},
    *,
};
use local::{error, other};
use std::{
    collections::BTreeMap,
    fs,
    path::{Path, PathBuf},
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
        mpsc,
    },
    thread,
    time::Duration,
};

pub type OpenFile = dyn Fn(&Path, Option<&str>) -> Result<(), FilesError> + Send + Sync;

pub struct Config {
    pub home: PathBuf,
    pub state_dir: PathBuf,
    pub ssh_config: PathBuf,
    pub known_hosts: PathBuf,
    /// Short, private directory for ControlMaster sockets (not persistent state).
    pub runtime_dir: PathBuf,
    /// Must marshal onto the application's UI thread if needed.
    pub open_directory: Arc<dyn Fn(Location) + Send + Sync>,
    pub open_file: Arc<OpenFile>,
    pub poll_interval: Duration,
}
impl Config {
    pub fn for_home(home: impl Into<PathBuf>) -> Self {
        let home = home.into();
        Self {
            state_dir: home.join(".local/state/hensou/files"),
            ssh_config: home.join(".ssh/config"),
            known_hosts: home.join(".ssh/known_hosts"),
            runtime_dir: home.join("run"),
            home,
            open_directory: Arc::new(|_| {}),
            open_file: Arc::new(open_file),
            poll_interval: Duration::from_secs(1),
        }
    }
}
impl Default for Config {
    fn default() -> Self {
        let mut config = Self::for_home(
            std::env::var_os("HOME")
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from("/")),
        );
        config.runtime_dir = std::env::var_os("XDG_RUNTIME_DIR")
            .map(PathBuf::from)
            .map(|p| p.join("hensou/ssh"))
            .unwrap_or_else(|| {
                PathBuf::from(format!(
                    "/tmp/hensou-ssh-{}",
                    rustix::process::getuid().as_raw()
                ))
            });
        if let Some(state) = std::env::var_os("XDG_STATE_HOME") {
            config.state_dir = PathBuf::from(state).join("hensou/files");
        }
        config
    }
}
fn open_file(path: &Path, desktop: Option<&str>) -> Result<(), FilesError> {
    let mut command = if let Some(id) = desktop {
        let mut c = std::process::Command::new("gtk-launch");
        c.arg(id);
        c
    } else {
        std::process::Command::new("xdg-open")
    };
    let status = command.arg(path).status().map_err(error)?;
    if status.success() {
        Ok(())
    } else {
        Err(other(format!("desktop handler failed: {status}")))
    }
}

enum BusMessage {
    Event(Box<Event>),
    Subscribe(EventSink),
}
#[derive(Clone)]
pub(crate) struct Bus(mpsc::Sender<BusMessage>);
impl Bus {
    fn new() -> Self {
        let (tx, rx) = mpsc::channel();
        thread::spawn(move || {
            let mut sinks: Vec<EventSink> = vec![];
            let mut snapshots = BTreeMap::<String, Event>::new();
            while let Ok(message) = rx.recv() {
                match message {
                    BusMessage::Subscribe(sink) => {
                        for e in snapshots.values() {
                            sink(e.clone());
                        }
                        sinks.push(sink);
                    }
                    BusMessage::Event(e) => {
                        let e = *e;
                        let key = match &e {
                            Event::Hosts { .. } => Some("hosts".into()),
                            Event::Volumes { .. } => Some("volumes".into()),
                            Event::Trash { .. } => Some("trash".into()),
                            Event::Transfer { transfer } => {
                                Some(format!("transfer:{}", transfer.id))
                            }
                            Event::WorkingCopy { copy } => {
                                Some(format!("working:{:?}", copy.remote))
                            }
                            Event::Connection { host, .. } => Some(format!("host:{host}")),
                            Event::WorkingCopyRemoved { remote } => {
                                snapshots.remove(&format!("working:{remote:?}"));
                                None
                            }
                            _ => None,
                        };
                        if let Some(key) = key {
                            snapshots.insert(key, e.clone());
                        }
                        for sink in &sinks {
                            sink(e.clone());
                        }
                    }
                }
            }
        });
        Self(tx)
    }
    pub(crate) fn emit(&self, event: Event) {
        let _ = self.0.send(BusMessage::Event(Box::new(event)));
    }
}
pub struct Files {
    commands: mpsc::Sender<(RequestId, Command)>,
    engine: Arc<Engine>,
}
pub(crate) struct Engine {
    config: Config,
    bus: Bus,
    trash: Arc<dyn TrashStore>,
    volumes: Arc<dyn VolumeMonitor>,
    runtime: tokio::runtime::Runtime,
    hosts: Mutex<BTreeMap<String, Arc<Mutex<remote::Host>>>>,
    watches: Mutex<BTreeMap<Location, Vec<Entry>>>,
    transfers: Mutex<BTreeMap<TransferId, Arc<transfer::Job>>>,
    working: Mutex<BTreeMap<Location, working::Copy>>,
    views: Mutex<()>,
    recovery: Mutex<()>,
    stopping: AtomicBool,
    network_changed: AtomicBool,
}
impl Files {
    pub fn new(
        config: Config,
        trash: Arc<dyn TrashStore>,
        volumes: Arc<dyn VolumeMonitor>,
    ) -> Result<Self, FilesError> {
        // OpenSSH adds a temporary suffix while binding the control socket.
        // Linux sockaddr_un.sun_path includes the final NUL byte (108 bytes).
        use std::os::unix::{ffi::OsStrExt, fs::MetadataExt};
        if config.runtime_dir.as_os_str().as_bytes().len()
            + b"/.ssh-connectionXXXXXX/master.XXXXXXXXXXXXXXXX".len()
            >= 108
        {
            return Err(other(
                "SSH runtime directory is too long for a Unix-domain socket",
            ));
        }
        fs::create_dir_all(&config.runtime_dir).map_err(error)?;
        let runtime_metadata = fs::symlink_metadata(&config.runtime_dir).map_err(error)?;
        if !runtime_metadata.is_dir()
            || runtime_metadata.uid() != rustix::process::getuid().as_raw()
        {
            return Err(other(
                "SSH runtime directory must be owned by the current user and must not be a symlink",
            ));
        }
        fs::create_dir_all(&config.state_dir).map_err(error)?;
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&config.runtime_dir, fs::Permissions::from_mode(0o700))
            .map_err(error)?;
        fs::set_permissions(&config.state_dir, fs::Permissions::from_mode(0o700)).map_err(error)?;
        let engine = Arc::new(Engine {
            config,
            bus: Bus::new(),
            trash,
            volumes,
            runtime: tokio::runtime::Builder::new_multi_thread()
                .worker_threads(2)
                .enable_all()
                .build()
                .map_err(error)?,
            hosts: Mutex::new(BTreeMap::new()),
            watches: Mutex::new(BTreeMap::new()),
            transfers: Mutex::new(BTreeMap::new()),
            working: Mutex::new(BTreeMap::new()),
            views: Mutex::new(()),
            recovery: Mutex::new(()),
            stopping: AtomicBool::new(false),
            network_changed: AtomicBool::new(false),
        });
        let (tx, rx) = mpsc::channel();
        let worker = engine.clone();
        thread::spawn(move || {
            worker.initialize();
            while let Ok((request, command)) = rx.recv() {
                if worker.stopping.load(Ordering::Relaxed) {
                    break;
                }
                if let Err(error) = worker.command(request, command) {
                    worker.bus.emit(Event::Error {
                        request: Some(request),
                        error,
                    });
                }
            }
        });
        let weak = Arc::downgrade(&engine);
        thread::spawn(move || {
            loop {
                let Some(engine) = weak.upgrade() else { break };
                if engine.stopping.load(Ordering::Relaxed) {
                    break;
                }
                let interval = engine.config.poll_interval;
                engine.poll();
                drop(engine);
                thread::sleep(interval);
            }
        });
        Ok(Self {
            commands: tx,
            engine,
        })
    }
    pub fn network_changed(&self) {
        self.engine.network_changed.store(true, Ordering::Relaxed);
    }
}
impl Drop for Files {
    fn drop(&mut self) {
        self.engine.stopping.store(true, Ordering::Relaxed);
    }
}
impl FilesService for Files {
    fn send(&self, request: RequestId, command: Command) {
        let _ = self.commands.send((request, command));
    }
    fn subscribe(&self, sink: EventSink) {
        let _ = self.engine.bus.0.send(BusMessage::Subscribe(sink));
    }
}
impl Engine {
    fn initialize(self: &Arc<Self>) {
        self.bus.emit(Event::Hosts {
            names: remote::host_names(&self.config.ssh_config),
        });
        self.bus.emit(Event::Volumes {
            volumes: self.volumes.volumes(),
        });
        self.refresh_trash();
        let bus = self.bus.clone();
        self.volumes.watch(Box::new(move |volumes| {
            bus.emit(Event::Volumes { volumes })
        }));
        let weak = Arc::downgrade(self);
        self.trash.watch(Box::new(move || {
            if let Some(e) = weak.upgrade() {
                e.refresh_trash();
            }
        }));
        transfer::recover(self);
        working::recover(self);
    }
    fn refresh_trash(&self) {
        match self.trash_items() {
            Ok(items) => self.bus.emit(Event::Trash { items }),
            Err(error) => self.bus.emit(Event::Error {
                request: None,
                error,
            }),
        }
    }
    fn poll(self: &Arc<Self>) {
        if self.network_changed.swap(false, Ordering::Relaxed) {
            for host in self.hosts.lock().unwrap().values() {
                host.lock().unwrap().retry_at = std::time::Instant::now();
            }
        }
        let locations: Vec<_> = self.watches.lock().unwrap().keys().cloned().collect();
        for location in locations {
            if let Ok(entries) = self.list(&location) {
                let mut watches = self.watches.lock().unwrap();
                if watches.get(&location) != Some(&entries) {
                    watches.insert(location.clone(), entries.clone());
                    self.bus.emit(Event::FolderChanged { location, entries });
                }
            }
        }
        remote::poll(self);
        working::poll(self);
    }
    fn command(self: &Arc<Self>, request: RequestId, command: Command) -> Result<(), FilesError> {
        if self.transfers.lock().unwrap().contains_key(&request) {
            return Err(other("duplicate request id"));
        }
        match command {
            Command::List { location } => {
                let entries = self.list(&location)?;
                self.watches
                    .lock()
                    .unwrap()
                    .insert(location.clone(), entries.clone());
                self.bus.emit(Event::Listing {
                    request,
                    location,
                    entries,
                });
            }
            Command::Info { location } => self.bus.emit(Event::Info {
                request,
                entry: self.info(&location)?,
            }),
            Command::Open { location } => {
                if !matches!(location.place, Place::Local | Place::Host { .. })
                    || self.is_directory(&location)?
                {
                    (self.config.open_directory)(location);
                } else if matches!(location.place, Place::Host { .. }) {
                    working::open(self, location, None)?;
                } else {
                    (self.config.open_file)(&location.path, None)?;
                }
                self.done(request);
            }
            Command::OpenWith {
                location,
                desktop_id,
            } => {
                if !desktop_id.ends_with(".desktop")
                    || desktop_id.contains('/')
                    || desktop_id.starts_with('-')
                {
                    return Err(other("invalid desktop id"));
                }
                if matches!(location.place, Place::Host { .. }) {
                    working::open(self, location, Some(&desktop_id))?;
                } else {
                    self.require_local(&location)?;
                    (self.config.open_file)(&location.path, Some(&desktop_id))?;
                }
                self.done(request);
            }
            Command::ListHandlers { location } => {
                let handlers = self.handlers(&location)?;
                self.bus.emit(Event::Handlers {
                    request,
                    location,
                    handlers,
                });
            }
            Command::Rename { location, new_name } => {
                local::name(&new_name)?;
                let mut target = location.clone();
                target.path = location
                    .path
                    .parent()
                    .ok_or_else(|| other("cannot rename root"))?
                    .join(new_name);
                self.rename(&location, &target, false)?;
                self.done(request);
            }
            Command::NewFolder { parent, name } => {
                local::name(&name)?;
                let location = Location {
                    place: parent.place,
                    path: parent.path.join(name),
                };
                self.mkdir(&location)?;
                self.done(request);
            }
            Command::SaveView { location, view } => {
                self.save_view(location, view)?;
                self.done(request);
            }
            Command::LoadView { location } => {
                let view = self
                    .load_views()?
                    .into_iter()
                    .find(|(l, _)| l == &location)
                    .map(|(_, v)| v)
                    .unwrap_or_default();
                self.bus.emit(Event::View {
                    request,
                    location,
                    view,
                });
            }
            Command::Eject { volume_id } => {
                self.volumes.eject(&volume_id)?;
                self.done(request);
            }
            Command::CheckDelete { locations } => {
                for location in &locations {
                    local::validate(location)?;
                }
                let results = locations
                    .into_iter()
                    .map(|l| {
                        let kind = self.delete_kind(&l);
                        (l, kind)
                    })
                    .collect();
                self.bus.emit(Event::DeleteCheck { request, results });
            }
            Command::MoveToTrash { locations } => {
                for l in locations {
                    local::validate(&l)?;
                    if l.place == Place::Local {
                        self.trash.trash(&l.path)?;
                    } else {
                        self.remote_trash(&l)?;
                    }
                }
                self.refresh_trash();
                self.done(request);
            }
            Command::DeletePermanently { locations } => {
                for l in locations {
                    self.remove(&l)?;
                }
                self.done(request);
            }
            Command::RestoreFromTrash { items } => {
                for l in items {
                    local::validate(&l)?;
                    if l.place == Place::Local {
                        self.trash.restore(&l.path)?;
                    } else {
                        self.remote_restore(&l)?;
                    }
                }
                self.refresh_trash();
                self.done(request);
            }
            Command::EmptyTrash => {
                self.empty_remote_trash()?;
                self.trash.empty()?;
                self.refresh_trash();
                self.done(request);
            }
            Command::Connect { host } => {
                remote::explicit_connect(self, &host)?;
                transfer::recover(self);
                self.refresh_trash();
                self.done(request);
            }
            Command::TrustHostKey { host, fingerprint } => {
                remote::trust(self, &host, &fingerprint)?;
                transfer::recover(self);
                self.refresh_trash();
                self.done(request);
            }
            Command::RejectHostKey { host } => {
                remote::reject(self, &host);
                self.done(request);
            }
            Command::Transfer {
                mode,
                sources,
                destination,
            } => transfer::start(self, request, mode, sources, destination, false)?,
            Command::Prepare { locations } => {
                if locations.iter().all(|l| l.place == Place::Local) {
                    for l in &locations {
                        local::validate(l)?;
                        self.info(l)?;
                    }
                    self.bus.emit(Event::Prepared {
                        request,
                        paths: locations.into_iter().map(|l| l.path).collect(),
                    });
                } else {
                    let destination = Location::local(
                        self.config
                            .state_dir
                            .join("prepared")
                            .join(request.to_string()),
                    );
                    fs::create_dir_all(&destination.path).map_err(error)?;
                    transfer::start(
                        self,
                        request,
                        TransferMode::Copy,
                        locations,
                        destination,
                        true,
                    )?;
                }
            }
            Command::CancelTransfer { id } => {
                self.job(id)?.cancel();
                self.done(request);
            }
            Command::ResolveConflict {
                id,
                choice,
                apply_to_all,
            } => {
                self.job(id)?.resolve(choice, apply_to_all);
                self.done(request);
            }
            Command::KeepWaiting { id, keep } => {
                let job = self.job(id)?;
                if !keep {
                    job.cancel();
                } else {
                    job.keep_waiting();
                }
                self.done(request);
            }
            Command::StopWatching { remote } => {
                working::stop(self, &remote)?;
                self.done(request);
            }
            Command::ResolveRemoteChange { remote, choice } => {
                working::resolve(self, &remote, choice)?;
                self.done(request);
            }
        }
        Ok(())
    }
    fn job(&self, id: u64) -> Result<Arc<transfer::Job>, FilesError> {
        self.transfers
            .lock()
            .unwrap()
            .get(&id)
            .cloned()
            .ok_or(FilesError::NotFound)
    }
    fn done(&self, request: u64) {
        self.bus.emit(Event::Done { request });
    }
    fn require_local(&self, l: &Location) -> Result<(), FilesError> {
        local::validate(l)?;
        if l.place == Place::Local {
            Ok(())
        } else {
            Err(FilesError::Unsupported {
                what: "operation requires a local path".into(),
            })
        }
    }
    fn load_views(&self) -> Result<Vec<(Location, ViewMemory)>, FilesError> {
        match fs::read(self.config.state_dir.join("views.json")) {
            Ok(data) => serde_json::from_slice(&data).map_err(other),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(vec![]),
            Err(e) => Err(error(e)),
        }
    }
    fn save_view(&self, location: Location, view: ViewMemory) -> Result<(), FilesError> {
        let _lock = self.views.lock().unwrap();
        let mut views = self.load_views()?;
        views.retain(|(l, _)| l != &location);
        views.push((location, view));
        atomic_json(&self.config.state_dir.join("views.json"), &views)
    }
    fn handlers(&self, l: &Location) -> Result<Vec<Handler>, FilesError> {
        local::validate(l)?;
        let mime = if matches!(l.place, Place::Host { .. }) {
            mime_guess::from_path(&l.path)
                .first_or_octet_stream()
                .essence_str()
                .to_owned()
        } else {
            self.require_local(l)?;
            let output = std::process::Command::new("xdg-mime")
                .args(["query", "filetype"])
                .arg(&l.path)
                .output()
                .map_err(error)?;
            if !output.status.success() {
                return Err(other("MIME detection failed"));
            }
            String::from_utf8_lossy(&output.stdout).trim().to_string()
        };
        let default = std::process::Command::new("xdg-mime")
            .args(["query", "default", &mime])
            .output()
            .map_err(error)?;
        let default = String::from_utf8_lossy(&default.stdout).trim().to_string();
        let data_home = std::env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| self.config.home.join(".local/share"));
        let mut dirs = vec![data_home];
        dirs.extend(std::env::split_paths(
            &std::env::var_os("XDG_DATA_DIRS")
                .unwrap_or_else(|| "/usr/local/share:/usr/share".into()),
        ));
        let mut handlers = BTreeMap::new();
        for dir in dirs {
            if let Ok(entries) = fs::read_dir(dir.join("applications")) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.extension().is_none_or(|e| e != "desktop") {
                        continue;
                    }
                    let fields = local::desktop_fields(&fs::read_to_string(&path).map_err(error)?);
                    if fields.get("Hidden").is_some_and(|v| v == "true")
                        || !fields
                            .get("MimeType")
                            .is_some_and(|v| v.split(';').any(|t| t == mime))
                    {
                        continue;
                    }
                    let id = entry.file_name().to_string_lossy().into_owned();
                    handlers.entry(id.clone()).or_insert(Handler {
                        name: fields.get("Name").cloned().unwrap_or_else(|| id.clone()),
                        icon: fields.get("Icon").cloned(),
                        is_default: id == default,
                        desktop_id: id,
                    });
                }
            }
        }
        Ok(handlers.into_values().collect())
    }
}
pub(crate) fn atomic_json(path: &Path, value: &impl serde::Serialize) -> Result<(), FilesError> {
    use std::io::Write;
    let temp = path.with_extension("json.new");
    let mut file = fs::File::create(&temp).map_err(error)?;
    file.write_all(&serde_json::to_vec(value).map_err(other)?)
        .map_err(error)?;
    file.sync_all().map_err(error)?;
    fs::rename(temp, path).map_err(error)?;
    if let Some(parent) = path.parent() {
        fs::File::open(parent)
            .map_err(error)?
            .sync_all()
            .map_err(error)?;
    }
    Ok(())
}
pub(crate) fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}
