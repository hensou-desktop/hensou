use super::*;
use std::os::unix::ffi::{OsStrExt, OsStringExt};
impl Engine {
    fn remote_trash_root(&self, name: &str, create: bool) -> Result<Location, FilesError> {
        let sftp = self.connection(name)?;
        let home = self.remote_result(
            &Location::host(name, "/"),
            self.runtime.block_on(sftp.fs().canonicalize(".")),
        )?;
        let root = Location::host(name, home.join(".local/share/Trash"));
        if create {
            // mkdir -p creates only the host user's own standard Trash. The
            // command adapter quotes arguments; no path is shell source.
            self.remote_command(
                name,
                "mkdir",
                &[
                    "-p".as_ref(),
                    "-m".as_ref(),
                    "700".as_ref(),
                    "--".as_ref(),
                    root.path.join("files").as_os_str(),
                    root.path.join("info").as_os_str(),
                ],
            )?;
        }
        Ok(root)
    }
    pub(crate) fn delete_kind(&self, l: &Location) -> DeleteKind {
        if l.place == Place::Local {
            return self.trash.delete_kind(&l.path);
        }
        let result = (|| {
            let Place::Host { name } = &l.place else {
                return Err(other("virtual places cannot be deleted"));
            };
            local::validate(l)?;
            let root = self.remote_trash_root(name, true)?;
            let source = self.remote_command(
                name,
                "stat",
                &[
                    "-c".as_ref(),
                    "%d".as_ref(),
                    "--".as_ref(),
                    l.path.as_os_str(),
                ],
            )?;
            let trash = self.remote_command(
                name,
                "stat",
                &[
                    "-c".as_ref(),
                    "%d".as_ref(),
                    "--".as_ref(),
                    root.path.join("files").as_os_str(),
                ],
            )?;
            if source != trash {
                return Err(other("The host Trash is on another filesystem."));
            }
            Ok(())
        })();
        match result {
            Ok(()) => DeleteKind::Trash,
            Err(e) => DeleteKind::Permanent {
                reason: {
                    eprintln!("hensou-files: no host Trash: {e:?}");
                    "This host has no Trash for this item, so deleting it is permanent.".into()
                },
            },
        }
    }
    pub(crate) fn remote_trash(&self, l: &Location) -> Result<(), FilesError> {
        if let DeleteKind::Permanent { reason } = self.delete_kind(l) {
            return Err(other(reason));
        }
        let Place::Host { name } = &l.place else {
            return Err(other("not a host"));
        };
        let root = self.remote_trash_root(name, true)?;
        let basename = l
            .path
            .file_name()
            .ok_or_else(|| other("cannot trash root"))?
            .to_string_lossy();
        let mut index = 0;
        let (stored, info) = loop {
            let filename = format!("{basename}.{}-{index}", now());
            let stored = Location::host(name, root.path.join("files").join(&filename));
            let info = Location::host(
                name,
                root.path.join("info").join(format!("{filename}.trashinfo")),
            );
            match self.info(&stored) {
                Err(FilesError::NotFound) => match self.write_chunk(&info, 0, &[], true) {
                    Ok(()) => break (stored, info),
                    Err(FilesError::AlreadyExists) => index += 1,
                    Err(e) => return Err(e),
                },
                Ok(_) => index += 1,
                Err(e) => return Err(e),
            }
        };
        let date = std::process::Command::new("date")
            .args(["+%Y-%m-%dT%H:%M:%S"])
            .output()
            .map_err(error)?;
        if !date.status.success() {
            return Err(other("cannot format Trash deletion date"));
        }
        let contents = format!(
            "[Trash Info]\nPath={}\nDeletionDate={}\n",
            encode(&l.path),
            String::from_utf8_lossy(&date.stdout).trim()
        );
        self.write_chunk(&info, 0, contents.as_bytes(), false)?;
        if let Err(e) = self.rename(l, &stored, false) {
            let _ = self.remove(&info);
            return Err(e);
        }
        Ok(())
    }
    fn host_trash_items(&self, name: &str) -> Result<Vec<TrashItem>, FilesError> {
        let root = self.remote_trash_root(name, false)?;
        let info_dir = Location::host(name, root.path.join("info"));
        let entries = match self.list(&info_dir) {
            Ok(entries) => entries,
            Err(FilesError::NotFound) => return Ok(vec![]),
            Err(e) => return Err(e),
        };
        let mut items = vec![];
        for info in entries {
            let Some(filename) = info.name.strip_suffix(".trashinfo") else {
                continue;
            };
            let bytes = self.read_chunk(&info.location, 0)?;
            let text = String::from_utf8_lossy(&bytes);
            let Some(path) = text.lines().find_map(|l| l.strip_prefix("Path=")) else {
                continue;
            };
            let path = decode(path)?;
            if !path.is_absolute() {
                continue;
            }
            let stored = Location::host(name, root.path.join("files").join(filename));
            match self.info(&stored) {
                Ok(mut entry) => {
                    entry.name = path
                        .file_name()
                        .unwrap_or(path.as_os_str())
                        .to_string_lossy()
                        .into_owned();
                    entry.hidden = entry.name.starts_with('.');
                    items.push(TrashItem {
                        original: Location::host(name, path),
                        stored,
                        deleted_at: None,
                        entry,
                    });
                }
                Err(FilesError::NotFound) => {}
                Err(e) => return Err(e),
            }
        }
        Ok(items)
    }
    pub(crate) fn trash_items(&self) -> Result<Vec<TrashItem>, FilesError> {
        let mut items = self.trash.items()?;
        for name in self.connected_hosts() {
            items.extend(self.host_trash_items(&name)?);
        }
        Ok(items)
    }
    pub(crate) fn remote_restore(&self, stored: &Location) -> Result<(), FilesError> {
        let Place::Host { name } = &stored.place else {
            return Err(other("not a host"));
        };
        let item = self
            .host_trash_items(name)?
            .into_iter()
            .find(|i| i.stored == *stored)
            .ok_or(FilesError::NotFound)?;
        self.rename(stored, &item.original, false)?;
        let root = self.remote_trash_root(name, false)?;
        self.remove(&Location::host(
            name,
            root.path.join("info").join(format!(
                "{}.trashinfo",
                stored.path.file_name().unwrap().to_string_lossy()
            )),
        ))
    }
    pub(crate) fn empty_remote_trash(&self) -> Result<(), FilesError> {
        for name in self.connected_hosts() {
            let root = self.remote_trash_root(&name, false)?;
            for item in self.host_trash_items(&name)? {
                self.remove(&item.stored)?;
                self.remove(&Location::host(
                    &name,
                    root.path.join("info").join(format!(
                        "{}.trashinfo",
                        item.stored.path.file_name().unwrap().to_string_lossy()
                    )),
                ))?;
            }
        }
        Ok(())
    }
}
fn encode(path: &Path) -> String {
    path.as_os_str()
        .as_bytes()
        .iter()
        .map(|b| {
            if b.is_ascii_alphanumeric() || b"/-_.~".contains(b) {
                (*b as char).to_string()
            } else {
                format!("%{b:02X}")
            }
        })
        .collect()
}
fn decode(s: &str) -> Result<PathBuf, FilesError> {
    let bytes = s.as_bytes();
    let mut result = vec![];
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' {
            let hex = bytes
                .get(i + 1..i + 3)
                .ok_or_else(|| other("invalid Trash path encoding"))?;
            let hex = std::str::from_utf8(hex).map_err(other)?;
            result.push(u8::from_str_radix(hex, 16).map_err(other)?);
            i += 3;
        } else {
            result.push(bytes[i]);
            i += 1;
        }
    }
    Ok(PathBuf::from(std::ffi::OsString::from_vec(result)))
}
