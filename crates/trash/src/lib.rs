//! Local freedesktop Trash with same-filesystem moves and external change watches.
use hensou_files_model::{
    DeleteKind, Entry, EntryKind, FilesError, IconHint, Location, TrashItem, platform::TrashStore,
};
use nix::{
    fcntl::{RenameFlags, renameat2},
    unistd::{AccessFlags, Uid, access},
};
use notify::Watcher;
use percent_encoding::{NON_ALPHANUMERIC, percent_decode_str, percent_encode};
use std::{
    fs::{self, OpenOptions},
    io::Write,
    os::unix::{
        ffi::{OsStrExt, OsStringExt},
        fs::{MetadataExt, PermissionsExt},
    },
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};

pub struct FreedesktopTrash {
    home: PathBuf,
    mounts: Vec<PathBuf>,
    lifetime: Arc<()>,
    operation: Mutex<()>,
}
fn error(e: impl std::fmt::Display) -> FilesError {
    FilesError::Other {
        message: e.to_string(),
    }
}
fn io_error(e: std::io::Error) -> FilesError {
    match e.kind() {
        std::io::ErrorKind::NotFound => FilesError::NotFound,
        std::io::ErrorKind::PermissionDenied => FilesError::PermissionDenied,
        std::io::ErrorKind::AlreadyExists => FilesError::AlreadyExists,
        _ => error(e),
    }
}
fn secure_dir(path: &Path) -> Result<(), FilesError> {
    match fs::symlink_metadata(path) {
        Ok(meta) => {
            if !meta.is_dir() || meta.uid() != Uid::current().as_raw() || meta.mode() & 0o077 != 0 {
                return Err(FilesError::PermissionDenied);
            }
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            use std::os::unix::fs::DirBuilderExt;
            fs::DirBuilder::new()
                .mode(0o700)
                .create(path)
                .map_err(io_error)?;
        }
        Err(e) => return Err(io_error(e)),
    }
    access(path, AccessFlags::W_OK | AccessFlags::X_OK).map_err(error)
}
fn prepare(root: &Path) -> Result<(), FilesError> {
    secure_dir(root)?;
    secure_dir(&root.join("files"))?;
    secure_dir(&root.join("info"))
}
/// Select a volume's spec-compliant Trash, rejecting symlinked/shared unsafe roots.
pub fn volume_trash(top: &Path) -> Result<PathBuf, FilesError> {
    let uid = Uid::current().to_string();
    let shared = top.join(".Trash");
    if fs::symlink_metadata(&shared).is_ok_and(|m| m.is_dir() && m.mode() & 0o1000 != 0) {
        let root = shared.join(&uid);
        if prepare(&root).is_ok() {
            return Ok(root);
        }
    }
    let root = top.join(format!(".Trash-{uid}"));
    prepare(&root)?;
    Ok(root)
}
impl FreedesktopTrash {
    pub fn new(home_trash: PathBuf, mounts: Vec<PathBuf>) -> Result<Self, FilesError> {
        if let Some(parent) = home_trash.parent() {
            fs::create_dir_all(parent).map_err(io_error)?;
        }
        prepare(&home_trash)?;
        Ok(Self {
            home: home_trash,
            mounts,
            lifetime: Arc::new(()),
            operation: Mutex::new(()),
        })
    }
    pub fn from_env() -> Result<Self, FilesError> {
        let data = std::env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".local/share")))
            .ok_or_else(|| error("HOME is unset"))?;
        Self::new(data.join("Trash"), Vec::new())
    }
    fn root_for(&self, path: &Path) -> Result<(PathBuf, Option<PathBuf>), FilesError> {
        if !path.is_absolute() || path.file_name().is_none() {
            return Err(error("Trash requires an absolute non-root path"));
        }
        let meta = fs::symlink_metadata(path).map_err(io_error)?;
        let parent = path
            .parent()
            .ok_or(FilesError::NotFound)?
            .canonicalize()
            .map_err(io_error)?;
        access(parent.as_path(), AccessFlags::W_OK | AccessFlags::X_OK).map_err(error)?;
        let normalized = parent.join(path.file_name().ok_or(FilesError::NotFound)?);
        if normalized.starts_with(&self.home) {
            return Err(error("already in Trash"));
        }
        if fs::metadata(&self.home).map_err(io_error)?.dev() == meta.dev() {
            prepare(&self.home)?;
            return Ok((self.home.clone(), None));
        }
        let top = mounted_paths(&self.mounts)
            .into_iter()
            .filter(|m| {
                normalized.starts_with(m) && fs::metadata(m).is_ok_and(|mm| mm.dev() == meta.dev())
            })
            .max_by_key(|m| m.components().count())
            .ok_or_else(|| error("no mounted filesystem Trash"))?;
        if normalized == top {
            return Err(error("cannot trash a mount point"));
        }
        let root = volume_trash(&top)?;
        if normalized.starts_with(&root) {
            return Err(error("already in Trash"));
        }
        Ok((root, Some(top)))
    }
    fn roots(&self) -> Vec<(PathBuf, Option<PathBuf>)> {
        trash_roots(&self.home, &self.mounts)
    }
    fn original(&self, stored: &Path) -> Result<(PathBuf, PathBuf, Option<i64>), FilesError> {
        let (root, top) = self
            .roots()
            .into_iter()
            .find(|(r, _)| stored.parent() == Some(r.join("files").as_path()))
            .ok_or(FilesError::PermissionDenied)?;
        let name = stored.file_name().ok_or(FilesError::NotFound)?;
        let mut info_name = name.to_os_string();
        info_name.push(".trashinfo");
        let info = root.join("info").join(info_name);
        let text = fs::read_to_string(&info).map_err(io_error)?;
        let encoded = text
            .lines()
            .find_map(|l| l.strip_prefix("Path="))
            .ok_or_else(|| error("invalid trashinfo"))?;
        let decoded = PathBuf::from(std::ffi::OsString::from_vec(
            percent_decode_str(encoded).collect(),
        ));
        if decoded
            .components()
            .any(|c| matches!(c, std::path::Component::ParentDir))
        {
            return Err(error("unsafe trashinfo path"));
        }
        let original = match top {
            Some(top) if !decoded.is_absolute() => top.join(decoded),
            _ => decoded,
        };
        if !original.is_absolute() {
            return Err(error("trashinfo path is not absolute"));
        }
        let deleted = text
            .lines()
            .find_map(|l| l.strip_prefix("DeletionDate="))
            .and_then(|s| chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%dT%H:%M:%S").ok())
            .and_then(|d| d.and_local_timezone(chrono::Local).single())
            .map(|d| d.timestamp());
        Ok((original, info, deleted))
    }
}
impl TrashStore for FreedesktopTrash {
    fn delete_kind(&self, path: &Path) -> DeleteKind {
        match self.root_for(path) {
            Ok(_) => DeleteKind::Trash,
            Err(e) => DeleteKind::Permanent {
                // User-visible: no storage words ("mount", "filesystem"),
                // which each theme names differently (CONTEXT.md, Volume).
                reason: {
                    eprintln!("hensou-trash: no Trash for {}: {e:?}", path.display());
                    "This item can only be deleted permanently.".into()
                },
            },
        }
    }
    fn trash(&self, path: &Path) -> Result<PathBuf, FilesError> {
        let _guard = self.operation.lock().unwrap();
        let (root, top) = self.root_for(path)?;
        let original = path
            .parent()
            .unwrap()
            .canonicalize()
            .map_err(io_error)?
            .join(path.file_name().unwrap());
        let record = top
            .as_ref()
            .and_then(|t| original.strip_prefix(t).ok())
            .unwrap_or(&original);
        for suffix in 0u64.. {
            let mut name = path.file_name().unwrap().to_os_string();
            if suffix > 0 {
                name.push(format!(".{suffix}"));
            }
            let stored = root.join("files").join(&name);
            let mut info_name = name;
            info_name.push(".trashinfo");
            let info = root.join("info").join(info_name);
            use std::os::unix::fs::OpenOptionsExt;
            let mut file = match OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(&info)
            {
                Ok(f) => f,
                Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(e) => return Err(io_error(e)),
            };
            let result = writeln!(
                file,
                "[Trash Info]\nPath={}\nDeletionDate={}",
                percent_encode(record.as_os_str().as_bytes(), NON_ALPHANUMERIC),
                chrono::Local::now().format("%Y-%m-%dT%H:%M:%S")
            )
            .and_then(|_| file.sync_all());
            if let Err(e) = result {
                let _ = fs::remove_file(info);
                return Err(io_error(e));
            }
            match renameat2(
                nix::fcntl::AT_FDCWD,
                path,
                nix::fcntl::AT_FDCWD,
                &stored,
                RenameFlags::RENAME_NOREPLACE,
            ) {
                Ok(()) => return Ok(stored),
                Err(e) => {
                    let _ = fs::remove_file(info);
                    if e != nix::errno::Errno::EEXIST {
                        return Err(error(e));
                    }
                }
            }
        }
        unreachable!()
    }
    fn items(&self) -> Result<Vec<TrashItem>, FilesError> {
        let mut items = Vec::new();
        for (root, _) in self.roots() {
            for entry in fs::read_dir(root.join("files")).map_err(io_error)? {
                let entry = entry.map_err(io_error)?;
                let stored = entry.path();
                let (original, _, deleted_at) = self.original(&stored)?;
                let meta = fs::symlink_metadata(&stored).map_err(io_error)?;
                let kind = if meta.is_symlink() {
                    EntryKind::Alias
                } else if meta.is_dir() {
                    EntryKind::Folder
                } else {
                    EntryKind::File
                };
                items.push(TrashItem {
                    original: Location::local(&original),
                    stored: Location::local(&stored),
                    deleted_at,
                    entry: Entry {
                        location: Location::local(stored),
                        name: original
                            .file_name()
                            .unwrap_or_default()
                            .to_string_lossy()
                            .into_owned(),
                        kind,
                        size: Some(meta.len()),
                        modified: Some(meta.mtime()),
                        hidden: false,
                        link_target: fs::read_link(entry.path()).ok(),
                        owner: Some(meta.uid().to_string()),
                        mode: Some(meta.permissions().mode()),
                        icon: IconHint {
                            name: if meta.is_dir() { "folder" } else { "document" }.into(),
                            launcher_icon: None,
                            launcher_name: None,
                        },
                    },
                });
            }
        }
        Ok(items)
    }
    fn restore(&self, stored: &Path) -> Result<PathBuf, FilesError> {
        let _guard = self.operation.lock().unwrap();
        let (original, info, _) = self.original(stored)?;
        renameat2(
            nix::fcntl::AT_FDCWD,
            stored,
            nix::fcntl::AT_FDCWD,
            &original,
            RenameFlags::RENAME_NOREPLACE,
        )
        .map_err(|e| {
            if e == nix::errno::Errno::EEXIST {
                FilesError::AlreadyExists
            } else {
                error(e)
            }
        })?;
        fs::remove_file(info).map_err(io_error)?;
        Ok(original)
    }
    fn empty(&self) -> Result<u64, FilesError> {
        let _guard = self.operation.lock().unwrap();
        let mut count = 0;
        for item in self.items()? {
            let stored = item.stored.path;
            let (_, info, _) = self.original(&stored)?;
            if fs::symlink_metadata(&stored).map_err(io_error)?.is_dir() {
                fs::remove_dir_all(stored).map_err(io_error)?;
            } else {
                fs::remove_file(stored).map_err(io_error)?;
            }
            fs::remove_file(info).map_err(io_error)?;
            count += 1;
        }
        Ok(count)
    }
    fn watch(&self, on_change: Box<dyn Fn() + Send + Sync>) {
        let callback: Arc<dyn Fn() + Send + Sync> = Arc::from(on_change);
        let events = callback.clone();
        if let Ok(mut watcher) =
            notify::recommended_watcher(move |event: notify::Result<notify::Event>| {
                if event.is_ok_and(|event| !matches!(event.kind, notify::EventKind::Access(_))) {
                    events();
                }
            })
        {
            let mut watched = std::collections::HashSet::new();
            for (root, _) in self.roots() {
                if watcher
                    .watch(&root, notify::RecursiveMode::Recursive)
                    .is_ok()
                {
                    watched.insert(root);
                }
            }
            let lifetime = Arc::downgrade(&self.lifetime);
            let home = self.home.clone();
            let mounts = self.mounts.clone();
            std::thread::spawn(move || {
                while lifetime.strong_count() > 0 {
                    std::thread::sleep(std::time::Duration::from_secs(1));
                    let roots = trash_roots(&home, &mounts)
                        .into_iter()
                        .map(|(p, _)| p)
                        .collect::<std::collections::HashSet<_>>();
                    let mut changed = false;
                    for root in roots.difference(&watched) {
                        if watcher
                            .watch(root, notify::RecursiveMode::Recursive)
                            .is_ok()
                        {
                            changed = true;
                        }
                    }
                    for root in watched.difference(&roots) {
                        let _ = watcher.unwatch(root);
                        changed = true;
                    }
                    watched = roots;
                    if changed {
                        callback();
                    }
                }
            });
        }
    }
}

fn mounted_paths(configured: &[PathBuf]) -> Vec<PathBuf> {
    let mut mounts = configured.to_vec();
    if let Ok(text) = fs::read_to_string("/proc/self/mountinfo") {
        mounts.extend(
            text.lines()
                .filter_map(|l| l.split_whitespace().nth(4))
                .map(|p| {
                    PathBuf::from(
                        p.replace("\\040", " ")
                            .replace("\\011", "\t")
                            .replace("\\134", "\\"),
                    )
                }),
        );
    }
    mounts.sort();
    mounts.dedup();
    mounts
}

fn trash_roots(home: &Path, mounts: &[PathBuf]) -> Vec<(PathBuf, Option<PathBuf>)> {
    let mut result = vec![(home.to_path_buf(), None)];
    for top in mounted_paths(mounts) {
        for root in [
            top.join(".Trash").join(Uid::current().to_string()),
            top.join(format!(".Trash-{}", Uid::current())),
        ] {
            if root.parent().is_some_and(|p| p.ends_with(".Trash"))
                && !fs::symlink_metadata(top.join(".Trash"))
                    .is_ok_and(|m| m.is_dir() && m.mode() & 0o1000 != 0)
            {
                continue;
            }
            if fs::symlink_metadata(&root).is_ok_and(|m| {
                m.is_dir() && m.uid() == Uid::current().as_raw() && m.mode() & 0o077 == 0
            }) {
                result.push((root, Some(top.clone())));
            }
        }
    }
    result
}
