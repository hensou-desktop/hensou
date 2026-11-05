use super::*;
use futures_util::TryStreamExt;
use openssh_sftp_client::{Sftp, metadata::MetaData};
use std::os::unix::fs::OpenOptionsExt;
use std::{
    io::{Read, Seek, SeekFrom, Write},
    process::Command as Process,
    time::Instant,
};
use tokio::io::AsyncSeekExt;

pub(crate) struct Host {
    connection: Option<Arc<Sftp>>,
    session: Option<Arc<openssh::Session>>,
    pending: Option<(String, HostKeyPrompt)>,
    blocked: bool,
    rejected: bool,
    pub retry_at: Instant,
    attempt: u32,
    since: i64,
    touched: Instant,
}
impl Default for Host {
    fn default() -> Self {
        Self {
            connection: None,
            session: None,
            pending: None,
            blocked: false,
            rejected: false,
            retry_at: Instant::now(),
            attempt: 0,
            since: now(),
            touched: Instant::now(),
        }
    }
}
pub(crate) fn host_names(path: &Path) -> Vec<String> {
    let mut names = vec![];
    if let Ok(text) = fs::read_to_string(path) {
        for line in text.lines() {
            let line = line.split('#').next().unwrap_or("").trim();
            let mut fields = line.split_whitespace();
            if fields
                .next()
                .is_some_and(|s| s.eq_ignore_ascii_case("Host"))
            {
                names.extend(
                    fields
                        .filter(|s| !s.contains(['*', '?', '!']) && !s.starts_with('-'))
                        .map(str::to_owned),
                );
            }
        }
    }
    names.sort();
    names.dedup();
    names
}
impl Engine {
    fn host(&self, name: &str) -> Result<Arc<Mutex<Host>>, FilesError> {
        if !host_names(&self.config.ssh_config)
            .iter()
            .any(|s| s == name)
        {
            return Err(other("not a concrete Host entry in SSH config"));
        }
        Ok(self
            .hosts
            .lock()
            .unwrap()
            .entry(name.into())
            .or_insert_with(|| Arc::new(Mutex::new(Host::default())))
            .clone())
    }
    pub(crate) fn connection(&self, name: &str) -> Result<Arc<Sftp>, FilesError> {
        let handle = self.host(name)?;
        let mut host = handle.lock().unwrap();
        host.touched = Instant::now();
        if host.blocked || host.rejected {
            return Err(FilesError::HostKeyRejected { host: name.into() });
        }
        if let Some(sftp) = &host.connection {
            return Ok(sftp.clone());
        }
        if host.pending.is_some() || Instant::now() < host.retry_at {
            return Err(FilesError::HostUnreachable { host: name.into() });
        }
        self.bus.emit(Event::Connection {
            host: name.into(),
            state: ConnectionState::Connecting,
        });
        let control = self.config.state_dir.join("ssh");
        fs::create_dir_all(&control).map_err(error)?;
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&control, fs::Permissions::from_mode(0o700)).map_err(error)?;
        // OpenSSH, not Files, evaluates the user's configuration. First-value-wins
        // gives these transport safeguards precedence over user Host blocks.
        let config = control.join(format!("config-{}", name.replace('/', "_")));
        let source = self
            .config
            .ssh_config
            .to_str()
            .ok_or_else(|| other("SSH config path is not UTF-8"))?;
        if source.contains(['\n', '\r', '"']) {
            return Err(other("unsupported SSH config path"));
        }
        fs::write(&config, format!("ServerAliveCountMax 3\nServerAliveInterval 15\nStrictHostKeyChecking yes\nInclude \"{source}\"\n")).map_err(error)?;
        let mut builder = openssh::SessionBuilder::default();
        builder
            .known_hosts_check(openssh::KnownHosts::Strict)
            .config_file(&config)
            .user_known_hosts_file(&self.config.known_hosts)
            .control_directory(&self.config.runtime_dir)
            .server_alive_interval(Duration::from_secs(15))
            .connect_timeout(Duration::from_secs(5));
        let result = self.runtime.block_on(async {
            let session = Arc::new(builder.connect_mux(name).await.map_err(ssh_error)?);
            let sftp = Sftp::from_clonable_session(session.clone(), Default::default())
                .await
                .map_err(ssh_error)?;
            Ok::<_, String>((session, sftp))
        });
        match result {
            Ok((session, sftp)) => {
                host.session = Some(session);
                let sftp = Arc::new(sftp);
                host.connection = Some(sftp.clone());
                host.attempt = 0;
                self.bus.emit(Event::Connection {
                    host: name.into(),
                    state: ConnectionState::Connected,
                });
                Ok(sftp)
            }
            Err(message) => {
                if message.contains("REMOTE HOST IDENTIFICATION HAS CHANGED")
                    || message.contains("Offending")
                {
                    host.blocked = true;
                    self.bus.emit(Event::Connection {
                        host: name.into(),
                        state: ConnectionState::HostKeyChanged {
                            fingerprint: scan(self, name)
                                .map(|(_, p)| p.fingerprint)
                                .unwrap_or_default(),
                        },
                    });
                    return Err(FilesError::HostKeyRejected { host: name.into() });
                }
                if message.contains("Host key verification failed")
                    || message.contains("No ED25519 host key is known")
                    || message.contains("No RSA host key is known")
                    || message.contains("No ECDSA host key is known")
                {
                    // A known identity that cannot verify is never offered as a new key.
                    if known(self, name)? {
                        host.blocked = true;
                        self.bus.emit(Event::Connection {
                            host: name.into(),
                            state: ConnectionState::HostKeyChanged {
                                fingerprint: scan(self, name)
                                    .map(|(_, p)| p.fingerprint)
                                    .unwrap_or_default(),
                            },
                        });
                        return Err(FilesError::HostKeyRejected { host: name.into() });
                    }
                    let (key, prompt) = scan(self, name)?;
                    host.pending = Some((key, prompt.clone()));
                    self.bus.emit(Event::HostKey { prompt });
                } else {
                    self.bus.emit(Event::Error {
                        request: None,
                        error: other(&message),
                    });
                    reconnect(self, name, &mut host);
                }
                Err(FilesError::HostUnreachable { host: name.into() })
            }
        }
    }
    pub(crate) fn remote_result<T>(
        &self,
        l: &Location,
        result: Result<T, openssh_sftp_client::Error>,
    ) -> Result<T, FilesError> {
        result.map_err(|e| {
            let text = e.to_string();
            // Status errors describe the operation, not a broken transport.
            if text.contains("No such file") || text.contains("NoSuchFile") {
                return FilesError::NotFound;
            }
            if text.contains("Permission denied") || text.contains("PermissionDenied") {
                return FilesError::PermissionDenied;
            }
            if text.contains("File exists") {
                return FilesError::AlreadyExists;
            }
            if matches!(e, openssh_sftp_client::Error::SftpError(..)) {
                return other(text);
            }
            if let Place::Host { name } = &l.place {
                if let Ok(h) = self.host(name) {
                    let mut h = h.lock().unwrap();
                    h.connection = None;
                    h.session = None;
                    reconnect(self, name, &mut h);
                }
                FilesError::HostUnreachable { host: name.clone() }
            } else {
                other(text)
            }
        })
    }
    pub(crate) fn remote_command(
        &self,
        name: &str,
        program: &str,
        args: &[&std::ffi::OsStr],
    ) -> Result<Vec<u8>, FilesError> {
        self.connection(name)?;
        let session = self
            .host(name)?
            .lock()
            .unwrap()
            .session
            .clone()
            .ok_or_else(|| other("missing SSH session"))?;
        let args = args
            .iter()
            .map(|arg| {
                arg.to_str()
                    .ok_or_else(|| other("remote command path is not UTF-8"))
            })
            .collect::<Result<Vec<_>, _>>()?;
        let output = self
            .runtime
            .block_on(session.command(program).args(args).output())
            .map_err(other)?;
        if output.status.success() {
            Ok(output.stdout)
        } else {
            Err(other(String::from_utf8_lossy(&output.stderr)))
        }
    }
    pub(crate) fn connected_hosts(&self) -> Vec<String> {
        self.hosts
            .lock()
            .unwrap()
            .iter()
            .filter_map(|(name, host)| {
                host.lock()
                    .unwrap()
                    .connection
                    .as_ref()
                    .map(|_| name.clone())
            })
            .collect()
    }
    pub(crate) fn canonicalize(&self, location: &Location) -> Result<PathBuf, FilesError> {
        local::validate(location)?;
        match &location.place {
            Place::Local => fs::canonicalize(&location.path).map_err(error),
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                self.remote_result(
                    location,
                    self.runtime
                        .block_on(sftp.fs().canonicalize(&location.path)),
                )
            }
            _ => Err(other("virtual location has no canonical path")),
        }
    }
    pub(crate) fn is_directory(&self, location: &Location) -> Result<bool, FilesError> {
        local::validate(location)?;
        match &location.place {
            Place::Local => Ok(fs::metadata(&location.path).map_err(error)?.is_dir()),
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                Ok(self
                    .remote_result(
                        location,
                        self.runtime.block_on(sftp.fs().metadata(&location.path)),
                    )?
                    .file_type()
                    .is_some_and(|t| t.is_dir()))
            }
            _ => Ok(true),
        }
    }
    pub(crate) fn info(&self, l: &Location) -> Result<Entry, FilesError> {
        local::validate(l)?;
        match &l.place {
            Place::Local => local::info(l),
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                let m = self.remote_result(
                    l,
                    self.runtime.block_on(sftp.fs().symlink_metadata(&l.path)),
                )?;
                let link = if m.file_type().is_some_and(|t| t.is_symlink()) {
                    Some(
                        self.remote_result(l, self.runtime.block_on(sftp.fs().read_link(&l.path)))?,
                    )
                } else {
                    None
                };
                let mut entry = entry(l.clone(), m, link);
                if entry.kind == EntryKind::Launcher && m.len().is_some_and(|len| len < 1024 * 1024)
                {
                    let bytes =
                        self.remote_result(l, self.runtime.block_on(sftp.fs().read(&l.path)))?;
                    let fields = local::desktop_fields(&String::from_utf8_lossy(&bytes));
                    entry.icon.launcher_icon = fields.get("Icon").cloned();
                    entry.icon.launcher_name = fields.get("Name").cloned();
                }
                Ok(entry)
            }
            _ => Err(FilesError::Unsupported {
                what: "virtual location has no filesystem metadata".into(),
            }),
        }
    }
    pub(crate) fn list(&self, l: &Location) -> Result<Vec<Entry>, FilesError> {
        local::validate(l)?;
        match &l.place {
            Place::Local => local::list(l),
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                let paths = self.remote_result(
                    l,
                    self.runtime.block_on(async {
                        let entries: Vec<_> = sftp
                            .fs()
                            .open_dir(&l.path)
                            .await?
                            .read_dir()
                            .try_collect()
                            .await?;
                        Ok(entries
                            .into_iter()
                            .map(|e| e.filename().to_path_buf())
                            .filter(|p| p != Path::new(".") && p != Path::new(".."))
                            .collect::<Vec<_>>())
                    }),
                )?;
                let mut entries = paths
                    .into_iter()
                    .map(|path| {
                        self.info(&Location {
                            place: l.place.clone(),
                            path: l.path.join(path),
                        })
                    })
                    .collect::<Result<Vec<_>, _>>()?;
                entries.sort_by(|a, b| a.name.cmp(&b.name));
                Ok(entries)
            }
            Place::Trash => Ok(self
                .trash_items()?
                .into_iter()
                .map(|i| Entry {
                    location: i.stored,
                    ..i.entry
                })
                .collect()),
            Place::SshHosts => Ok(host_names(&self.config.ssh_config)
                .into_iter()
                .map(|name| virtual_entry(Location::host(&name, "/"), &name, EntryKind::Host))
                .collect()),
            Place::Computer => {
                let mut entries = vec![
                    virtual_entry(
                        Location::local(&self.config.home),
                        "Home",
                        EntryKind::Folder,
                    ),
                    virtual_entry(
                        Location::virtual_place(Place::SshHosts),
                        "SSH Hosts",
                        EntryKind::SshHosts,
                    ),
                    virtual_entry(
                        Location::virtual_place(Place::Trash),
                        "Trash",
                        EntryKind::Trash,
                    ),
                ];
                entries.extend(self.volumes.volumes().into_iter().filter_map(|v| {
                    v.mount_point
                        .map(|p| virtual_entry(Location::local(p), &v.label, EntryKind::Volume))
                }));
                Ok(entries)
            }
        }
    }
    pub(crate) fn rename(
        &self,
        from: &Location,
        to: &Location,
        replace: bool,
    ) -> Result<(), FilesError> {
        local::validate(from)?;
        local::validate(to)?;
        if from.place != to.place {
            return Err(other("rename cannot cross places"));
        }
        if !replace {
            match self.info(to) {
                Ok(_) => return Err(FilesError::AlreadyExists),
                Err(FilesError::NotFound) => {}
                Err(e) => return Err(e),
            }
        }
        match &from.place {
            Place::Local => {
                if replace {
                    fs::rename(&from.path, &to.path).map_err(error)
                } else {
                    rustix::fs::renameat_with(
                        rustix::fs::CWD,
                        &from.path,
                        rustix::fs::CWD,
                        &to.path,
                        rustix::fs::RenameFlags::NOREPLACE,
                    )
                    .map_err(|e| error(e.into()))
                }
            }
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                if !replace && self.info(from)?.kind != EntryKind::Folder {
                    // The high-level SFTP rename always uses posix-rename,
                    // which overwrites a racing file. Hard-link publication
                    // gives files an atomic no-clobber commit on OpenSSH.
                    self.remote_result(
                        from,
                        self.runtime
                            .block_on(sftp.fs().hard_link(&from.path, &to.path)),
                    )?;
                    return self.remote_result(
                        from,
                        self.runtime.block_on(sftp.fs().remove_file(&from.path)),
                    );
                }
                self.remote_result(
                    from,
                    self.runtime
                        .block_on(sftp.fs().rename(&from.path, &to.path)),
                )
            }
            _ => Err(other("cannot rename a virtual place")),
        }
    }
    pub(crate) fn mkdir(&self, l: &Location) -> Result<(), FilesError> {
        local::validate(l)?;
        match &l.place {
            Place::Local => fs::create_dir(&l.path).map_err(error),
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                self.remote_result(l, self.runtime.block_on(sftp.fs().create_dir(&l.path)))
            }
            _ => Err(other("cannot create in virtual place")),
        }
    }
    pub(crate) fn remove(&self, l: &Location) -> Result<(), FilesError> {
        local::validate(l)?;
        if l.path.parent().is_none() {
            return Err(other("refusing to remove filesystem root"));
        }
        match &l.place {
            Place::Local => local::remove(&l.path),
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                if self.info(l)?.kind == EntryKind::Folder {
                    for child in self.list(l)? {
                        self.remove(&child.location)?;
                    }
                    self.remote_result(l, self.runtime.block_on(sftp.fs().remove_dir(&l.path)))
                } else {
                    self.remote_result(l, self.runtime.block_on(sftp.fs().remove_file(&l.path)))
                }
            }
            _ => Err(other("cannot remove virtual place")),
        }
    }
    pub(crate) fn read_chunk(&self, l: &Location, offset: u64) -> Result<Vec<u8>, FilesError> {
        match &l.place {
            Place::Local => {
                if !fs::metadata(&l.path).map_err(error)?.is_file() {
                    return Err(other("only regular files can be copied as bytes"));
                }
                let mut file = fs::OpenOptions::new()
                    .read(true)
                    .custom_flags(rustix::fs::OFlags::NOFOLLOW.bits() as i32)
                    .open(&l.path)
                    .map_err(error)?;
                file.seek(SeekFrom::Start(offset)).map_err(error)?;
                let mut bytes = vec![0; 128 * 1024];
                let n = file.read(&mut bytes).map_err(error)?;
                bytes.truncate(n);
                Ok(bytes)
            }
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                self.remote_result(
                    l,
                    self.runtime.block_on(async {
                        let mut file = sftp.open(&l.path).await?;
                        file.seek(SeekFrom::Start(offset)).await?;
                        let bytes = file
                            .read(128 * 1024, Default::default())
                            .await?
                            .unwrap_or_default()
                            .to_vec();
                        file.close().await?;
                        Ok(bytes)
                    }),
                )
            }
            _ => Err(other("cannot read virtual place")),
        }
    }
    pub(crate) fn write_chunk(
        &self,
        l: &Location,
        offset: u64,
        bytes: &[u8],
        create: bool,
    ) -> Result<(), FilesError> {
        match &l.place {
            Place::Local => {
                let mut file = fs::OpenOptions::new()
                    .write(true)
                    .create_new(create)
                    .custom_flags(rustix::fs::OFlags::NOFOLLOW.bits() as i32)
                    .open(&l.path)
                    .map_err(error)?;
                file.seek(SeekFrom::Start(offset)).map_err(error)?;
                file.write_all(bytes).map_err(error)?;
                file.sync_data().map_err(error)
            }
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                self.remote_result(
                    l,
                    self.runtime.block_on(async {
                        let mut options = sftp.options();
                        options.write(true).create_new(create);
                        let mut file = options.open(&l.path).await?;
                        file.seek(SeekFrom::Start(offset)).await?;
                        file.write_all(bytes).await?;
                        file.close().await
                    }),
                )
            }
            _ => Err(other("cannot write virtual place")),
        }
    }
    pub(crate) fn copy_mode(&self, l: &Location, mode: Option<u32>) -> Result<(), FilesError> {
        let Some(mode) = mode else { return Ok(()) };
        match &l.place {
            Place::Local => {
                use std::os::unix::fs::PermissionsExt;
                fs::set_permissions(&l.path, fs::Permissions::from_mode(mode & 0o777))
                    .map_err(error)
            }
            Place::Host { name } => {
                use openssh_sftp_client::metadata::{Permissions, RawPermissions};
                let sftp = self.connection(name)?;
                let permissions =
                    Permissions::from_raw(RawPermissions::from_bits_truncate(mode & 0o777));
                self.remote_result(
                    l,
                    self.runtime
                        .block_on(sftp.fs().set_permissions(&l.path, permissions)),
                )
            }
            _ => Err(other("cannot set permissions on virtual place")),
        }
    }
    pub(crate) fn symlink(&self, target: &Path, l: &Location) -> Result<(), FilesError> {
        match &l.place {
            Place::Local => std::os::unix::fs::symlink(target, &l.path).map_err(error),
            Place::Host { name } => {
                let sftp = self.connection(name)?;
                self.remote_result(l, self.runtime.block_on(sftp.fs().symlink(target, &l.path)))
            }
            _ => Err(other("cannot create alias in virtual place")),
        }
    }
}
fn entry(location: Location, m: MetaData, link_target: Option<PathBuf>) -> Entry {
    let kind = local::kind(
        &location.path,
        m.file_type().is_some_and(|t| t.is_dir()),
        m.file_type().is_some_and(|t| t.is_symlink()),
    );
    let name = location
        .path
        .file_name()
        .unwrap_or(location.path.as_os_str())
        .to_string_lossy()
        .into_owned();
    Entry {
        name: name.clone(),
        hidden: name.starts_with('.'),
        kind,
        size: if m.file_type().is_some_and(|t| t.is_dir()) {
            None
        } else {
            m.len()
        },
        modified: m.modified().map(|t| i64::from(t.into_raw())),
        owner: m.uid().map(|u| u.to_string()),
        mode: m.permissions().map(|p| p.as_raw().bits()),
        link_target,
        icon: IconHint {
            name: if m.file_type().is_some_and(|t| t.is_dir()) {
                "folder"
            } else {
                "application-octet-stream"
            }
            .into(),
            launcher_icon: None,
            launcher_name: None,
        },
        location,
    }
}
fn virtual_entry(location: Location, name: &str, kind: EntryKind) -> Entry {
    Entry {
        location,
        name: name.into(),
        kind,
        size: None,
        modified: None,
        hidden: false,
        link_target: None,
        owner: None,
        mode: None,
        icon: IconHint {
            name: match kind {
                EntryKind::Trash => "user-trash",
                EntryKind::Host => "network-server",
                EntryKind::SshHosts => "network-workgroup",
                EntryKind::Volume => "drive-removable-media",
                _ => "folder",
            }
            .into(),
            launcher_icon: None,
            launcher_name: None,
        },
    }
}
fn resolved(engine: &Engine, name: &str) -> Result<BTreeMap<String, String>, FilesError> {
    let result = Process::new("ssh")
        .arg("-G")
        .arg("-F")
        .arg(&engine.config.ssh_config)
        .arg(name)
        .output()
        .map_err(error)?;
    if !result.status.success() {
        return Err(other(String::from_utf8_lossy(&result.stderr)));
    }
    Ok(String::from_utf8_lossy(&result.stdout)
        .lines()
        .filter_map(|l| l.split_once(' ').map(|(k, v)| (k.to_owned(), v.to_owned())))
        .collect())
}
fn identity(fields: &BTreeMap<String, String>) -> Result<String, FilesError> {
    if let Some(alias) = fields.get("hostkeyalias") {
        return Ok(alias.clone());
    }
    let host = fields
        .get("hostname")
        .ok_or_else(|| other("SSH did not resolve hostname"))?;
    let port = fields.get("port").map(String::as_str).unwrap_or("22");
    Ok(if port == "22" {
        host.clone()
    } else {
        format!("[{host}]:{port}")
    })
}
fn known(engine: &Engine, name: &str) -> Result<bool, FilesError> {
    if !engine.config.known_hosts.exists() {
        return Ok(false);
    }
    let result = Process::new("ssh-keygen")
        .arg("-F")
        .arg(identity(&resolved(engine, name)?)?)
        .arg("-f")
        .arg(&engine.config.known_hosts)
        .output()
        .map_err(error)?;
    Ok(result.status.success())
}
fn scan(engine: &Engine, name: &str) -> Result<(String, HostKeyPrompt), FilesError> {
    let fields = resolved(engine, name)?;
    let hostname = fields
        .get("hostname")
        .ok_or_else(|| other("missing hostname"))?;
    let result = Process::new("ssh-keyscan")
        .args([
            "-T",
            "5",
            "-t",
            "ed25519,rsa,ecdsa",
            "-p",
            fields.get("port").map(String::as_str).unwrap_or("22"),
        ])
        .arg(hostname)
        .output()
        .map_err(error)?;
    let text = String::from_utf8_lossy(&result.stdout);
    let fields_key: Vec<_> = text
        .lines()
        .find(|l| !l.starts_with('#'))
        .ok_or_else(|| other("ssh-keyscan returned no key"))?
        .split_whitespace()
        .collect();
    if fields_key.len() != 3 {
        return Err(other("malformed scanned key"));
    }
    let key = format!(
        "{} {} {}\n",
        identity(&fields)?,
        fields_key[1],
        fields_key[2]
    );
    let path = engine
        .config
        .state_dir
        .join(format!("scan-{}.pub", name.replace('/', "_")));
    fs::write(&path, &key).map_err(error)?;
    let output = Process::new("ssh-keygen")
        .args(["-l", "-E", "sha256", "-f"])
        .arg(&path)
        .output()
        .map_err(error)?;
    fs::remove_file(path).map_err(error)?;
    if !output.status.success() {
        return Err(other("cannot fingerprint scanned key"));
    }
    let fingerprint = String::from_utf8_lossy(&output.stdout)
        .split_whitespace()
        .nth(1)
        .ok_or_else(|| other("missing fingerprint"))?
        .to_owned();
    Ok((
        key,
        HostKeyPrompt {
            host: name.into(),
            algorithm: fields_key[1].into(),
            fingerprint,
        },
    ))
}
pub(crate) fn trust(engine: &Engine, name: &str, fingerprint: &str) -> Result<(), FilesError> {
    let h = engine.host(name)?;
    {
        let mut host = h.lock().unwrap();
        if host.blocked || host.rejected {
            return Err(FilesError::HostKeyRejected { host: name.into() });
        }
        let (key, prompt) = host
            .pending
            .as_ref()
            .ok_or_else(|| other("no pending host key"))?;
        if prompt.fingerprint != fingerprint {
            return Err(FilesError::HostKeyRejected { host: name.into() });
        }
        if known(engine, name)? {
            return Err(FilesError::HostKeyRejected { host: name.into() });
        }
        if let Some(parent) = engine.config.known_hosts.parent() {
            fs::create_dir_all(parent).map_err(error)?;
        }
        let mut file = fs::OpenOptions::new()
            .append(true)
            .create(true)
            .open(&engine.config.known_hosts)
            .map_err(error)?;
        file.write_all(format!("\n{key}").as_bytes())
            .map_err(error)?;
        file.sync_all().map_err(error)?;
        host.pending = None;
        host.retry_at = Instant::now();
    }
    engine.connection(name)?;
    Ok(())
}
pub(crate) fn explicit_connect(engine: &Engine, name: &str) -> Result<(), FilesError> {
    {
        let handle = engine.host(name)?;
        let mut host = handle.lock().unwrap();
        host.rejected = false;
        host.retry_at = Instant::now();
    }
    engine.connection(name)?;
    Ok(())
}
pub(crate) fn reject(engine: &Engine, name: &str) {
    if let Ok(h) = engine.host(name) {
        let mut host = h.lock().unwrap();
        host.pending = None;
        host.rejected = true;
    }
    engine.bus.emit(Event::Error {
        request: None,
        error: FilesError::HostKeyRejected { host: name.into() },
    });
}
fn reconnect(engine: &Engine, name: &str, host: &mut Host) {
    if host.attempt == 0 {
        host.since = now();
    }
    host.attempt = host.attempt.saturating_add(1);
    host.retry_at = Instant::now()
        + Duration::from_secs((1u64 << host.attempt.saturating_sub(1).min(5)).min(30));
    engine.bus.emit(Event::Connection {
        host: name.into(),
        state: ConnectionState::Reconnecting {
            since: host.since,
            attempt: host.attempt,
        },
    });
}
pub(crate) fn poll(engine: &Engine) {
    let hosts: Vec<_> = engine
        .hosts
        .lock()
        .unwrap()
        .iter()
        .map(|(n, h)| (n.clone(), h.clone()))
        .collect();
    for (name, h) in hosts {
        let retry = {
            let mut host = h.lock().unwrap();
            if let Some(session) = host.session.as_ref()
                && engine.runtime.block_on(session.check()).is_err()
            {
                host.connection = None;
                host.session = None;
                reconnect(engine, &name, &mut host);
            }
            if host.connection.is_some() && host.touched.elapsed() > Duration::from_secs(600) {
                host.connection = None;
                host.session = None;
                engine.bus.emit(Event::Connection {
                    host: name.clone(),
                    state: ConnectionState::Idle,
                });
            }
            !host.blocked
                && !host.rejected
                && host.pending.is_none()
                && host.connection.is_none()
                && host.attempt > 0
                && Instant::now() >= host.retry_at
        };
        if retry && engine.connection(&name).is_ok() {
            transfer::recover(engine);
        }
    }
}

fn ssh_error(error: impl std::error::Error) -> String {
    let mut message = error.to_string();
    let mut source = error.source();
    while let Some(error) = source {
        message.push_str(": ");
        message.push_str(&error.to_string());
        source = error.source();
    }
    message
}
