use super::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Serialize, Deserialize)]
pub(crate) struct Copy {
    view: WorkingCopy,
    baseline: (Option<u64>, Option<i64>),
    local_stamp: (u64, u128),
    opened: i64,
    dirty: bool,
    #[serde(default)]
    upload_partial: Option<Location>,
}
fn stamp(path: &Path) -> Result<(u64, u128), FilesError> {
    let m = fs::metadata(path).map_err(error)?;
    Ok((
        m.len(),
        m.modified()
            .map_err(error)?
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos(),
    ))
}
/// Each working copy has a directory holding `.hensou-record.json` and a
/// `file/` folder with the payload under its remote name.
const PAYLOAD: &str = "file";

fn record_path(local: &Path) -> PathBuf {
    local
        .parent()
        .and_then(Path::parent)
        .expect("working copies live in <directory>/file/<name>")
        .join(".hensou-record.json")
}

fn persist(engine: &Engine, copy: &Copy) -> Result<(), FilesError> {
    atomic_json(&record_path(&copy.view.local), copy)?;
    engine.bus.emit(Event::WorkingCopy {
        copy: copy.view.clone(),
    });
    Ok(())
}
pub(crate) fn open(
    engine: &Engine,
    remote: Location,
    desktop: Option<&str>,
) -> Result<(), FilesError> {
    if let Some(copy) = engine.working.lock().unwrap().get(&remote) {
        return (engine.config.open_file)(&copy.view.local, desktop);
    }
    let info = engine.info(&remote)?;
    let root = engine.config.state_dir.join("working");
    fs::create_dir_all(&root).map_err(error)?;
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(&root, fs::Permissions::from_mode(0o700)).map_err(error)?;
    let mut n = 0;
    let directory = loop {
        let d = root.join(format!("{}-{n}", now()));
        match fs::create_dir(&d) {
            Ok(()) => break d,
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => n += 1,
            Err(e) => return Err(error(e)),
        }
    };
    // The payload lives in its own folder, so no remote file name can
    // collide with the tracking record beside it.
    let payload = directory.join(PAYLOAD);
    fs::create_dir(&payload).map_err(error)?;
    let local = payload.join(
        remote
            .path
            .file_name()
            .ok_or_else(|| other("cannot open root as working copy"))?,
    );
    let destination = Location::local(&local);
    engine.write_chunk(&destination, 0, &[], true)?;
    let mut offset = 0;
    loop {
        let bytes = engine.read_chunk(&remote, offset)?;
        if bytes.is_empty() {
            break;
        }
        engine.write_chunk(&destination, offset, &bytes, false)?;
        offset += bytes.len() as u64;
    }
    let after = engine.info(&remote)?;
    if (after.size, after.modified) != (info.size, info.modified) {
        return Err(other("remote changed while downloading working copy"));
    }
    let copy = Copy {
        view: WorkingCopy {
            remote: remote.clone(),
            local: local.clone(),
            last_saved: None,
            state: WorkingCopyState::Watching,
        },
        baseline: (info.size, info.modified),
        local_stamp: stamp(&local)?,
        opened: now(),
        dirty: false,
        upload_partial: None,
    };
    persist(engine, &copy)?;
    engine.working.lock().unwrap().insert(remote, copy);
    (engine.config.open_file)(&local, desktop)
}
fn upload(
    engine: &Engine,
    copy: &mut Copy,
    overwrite: bool,
    save_as: bool,
) -> Result<(), FilesError> {
    if let Some(partial) = &copy.upload_partial {
        match engine.remove(partial) {
            Ok(()) | Err(FilesError::NotFound) => {}
            Err(e) => return Err(e),
        }
        copy.upload_partial = None;
    }
    let before = match engine.info(&copy.view.remote) {
        Ok(entry) => Some(entry),
        Err(FilesError::NotFound) => None,
        Err(e) => return Err(e),
    };
    let version = before
        .as_ref()
        .map(|e| (e.size, e.modified))
        .unwrap_or((None, None));
    if !overwrite && version != copy.baseline {
        copy.view.state = WorkingCopyState::RemoteChanged;
        return persist(engine, copy);
    }
    copy.view.state = WorkingCopyState::Uploading;
    persist(engine, copy)?;
    let local_stamp = stamp(&copy.view.local)?;
    let mut destination = copy.view.remote.clone();
    if save_as {
        let original = destination.path.clone();
        let mut n = 1;
        loop {
            destination.path = original.with_file_name(format!(
                "{} (edited copy {n})",
                original.file_name().unwrap().to_string_lossy()
            ));
            match engine.info(&destination) {
                Err(FilesError::NotFound) => break,
                Ok(_) => n += 1,
                Err(e) => return Err(e),
            }
        }
    }
    let temp = Location {
        place: destination.place.clone(),
        path: destination.path.with_file_name(format!(
            ".hensou-working-{}-{}",
            std::process::id(),
            now()
        )),
    };
    copy.upload_partial = Some(temp.clone());
    persist(engine, copy)?;
    engine.write_chunk(&temp, 0, &[], true)?;
    let result = (|| {
        let mut offset = 0;
        loop {
            let bytes = engine.read_chunk(&Location::local(&copy.view.local), offset)?;
            if bytes.is_empty() {
                break;
            }
            engine.write_chunk(&temp, offset, &bytes, false)?;
            offset += bytes.len() as u64;
        }
        if stamp(&copy.view.local)? != local_stamp {
            return Err(other(
                "working copy changed during upload; retrying next poll",
            ));
        }
        engine.copy_mode(&temp, before.as_ref().and_then(|entry| entry.mode))?;
        let current = match engine.info(&copy.view.remote) {
            Ok(entry) => (entry.size, entry.modified),
            Err(FilesError::NotFound) => (None, None),
            Err(e) => return Err(e),
        };
        if !overwrite && current != copy.baseline {
            copy.view.state = WorkingCopyState::RemoteChanged;
            persist(engine, copy)?;
            return Ok(false);
        }
        engine.rename(&temp, &destination, !save_as)?;
        Ok(true)
    })();
    if !matches!(result, Ok(true))
        && matches!(engine.remove(&temp), Ok(()) | Err(FilesError::NotFound))
    {
        copy.upload_partial = None;
    }
    if result? {
        copy.upload_partial = None;
        if save_as {
            copy.view.remote = destination;
        }
        let current = engine.info(&copy.view.remote)?;
        copy.baseline = (current.size, current.modified);
        copy.local_stamp = local_stamp;
        copy.dirty = false;
        copy.view.state = WorkingCopyState::Watching;
        persist(engine, copy)?;
    }
    Ok(())
}
pub(crate) fn poll(engine: &Engine) {
    let mut copies = engine.working.lock().unwrap();
    let mut expired = vec![];
    for (remote, copy) in copies.iter_mut() {
        let result = (|| {
            let saved = stamp(&copy.view.local)?;
            if saved != copy.local_stamp {
                copy.local_stamp = saved;
                copy.dirty = true;
                copy.view.last_saved = Some(now());
            }
            if copy.dirty && copy.view.state != WorkingCopyState::RemoteChanged {
                upload(engine, copy, false, false)?;
            }
            if !copy.dirty && now() - copy.view.last_saved.unwrap_or(copy.opened) >= 7 * 24 * 3600 {
                expired.push(remote.clone());
            }
            Ok::<_, FilesError>(())
        })();
        if let Err(error) = result {
            copy.view.state = if matches!(error, FilesError::HostUnreachable { .. }) {
                WorkingCopyState::UploadQueued
            } else {
                WorkingCopyState::Failed {
                    reason: format!("{error:?}"),
                }
            };
            let _ = persist(engine, copy);
        }
    }
    drop(copies);
    for remote in expired {
        let _ = stop(engine, &remote);
    }
}
pub(crate) fn stop(engine: &Engine, remote: &Location) -> Result<(), FilesError> {
    let mut copies = engine.working.lock().unwrap();
    let copy = copies.get(remote).ok_or(FilesError::NotFound)?;
    // Retain unuploaded bytes even when explicitly stopping the watch.
    if !copy.dirty && stamp(&copy.view.local)? == copy.local_stamp {
        fs::remove_file(&copy.view.local).map_err(error)?;
        fs::remove_file(record_path(&copy.view.local)).map_err(error)?;
    }
    let _ = fs::remove_file(record_path(&copy.view.local));
    copies.remove(remote);
    engine.bus.emit(Event::WorkingCopyRemoved {
        remote: remote.clone(),
    });
    Ok(())
}
pub(crate) fn resolve(
    engine: &Engine,
    remote: &Location,
    choice: RemoteChangeChoice,
) -> Result<(), FilesError> {
    let mut copies = engine.working.lock().unwrap();
    let copy = copies.get_mut(remote).ok_or(FilesError::NotFound)?;
    if copy.view.state != WorkingCopyState::RemoteChanged {
        return Err(other("working copy has no remote conflict"));
    }
    match choice {
        RemoteChangeChoice::Overwrite => upload(engine, copy, true, false),
        RemoteChangeChoice::SaveAsCopy => {
            upload(engine, copy, true, true)?;
            let saved = copy.clone();
            copies.remove(remote);
            engine.bus.emit(Event::WorkingCopyRemoved {
                remote: remote.clone(),
            });
            copies.insert(saved.view.remote.clone(), saved);
            Ok(())
        }
        RemoteChangeChoice::KeepRemote => {
            // Keep the user's unsent local bytes as an unwatched copy.
            fs::remove_file(record_path(&copy.view.local)).map_err(error)?;
            copies.remove(remote);
            engine.bus.emit(Event::WorkingCopyRemoved {
                remote: remote.clone(),
            });
            Ok(())
        }
    }
}

pub(crate) fn recover(engine: &Engine) {
    let Ok(directories) = fs::read_dir(engine.config.state_dir.join("working")) else {
        return;
    };
    for directory in directories.flatten() {
        let record = directory.path().join(".hensou-record.json");
        let result = (|| {
            let mut copy: Copy =
                serde_json::from_slice(&fs::read(record).map_err(error)?).map_err(other)?;
            if !copy.view.local.starts_with(directory.path().join(PAYLOAD)) {
                return Err(other("working copy record escapes its directory"));
            }
            if stamp(&copy.view.local)? != copy.local_stamp {
                copy.dirty = true;
                copy.view.last_saved = Some(now());
            }
            if copy.dirty {
                copy.view.state = WorkingCopyState::UploadQueued;
            }
            engine.bus.emit(Event::WorkingCopy {
                copy: copy.view.clone(),
            });
            engine
                .working
                .lock()
                .unwrap()
                .insert(copy.view.remote.clone(), copy);
            Ok::<_, FilesError>(())
        })();
        if let Err(error) = result
            && error != FilesError::NotFound
        {
            engine.bus.emit(Event::Error {
                request: None,
                error,
            });
        }
    }
}

#[cfg(test)]
mod layout_tests {
    use super::{PAYLOAD, record_path};
    use std::path::Path;

    #[test]
    fn a_remote_file_named_like_the_record_never_collides_with_it() {
        let directory = Path::new("/state/working/1-0");
        for name in [".hensou-record.json", ".hensou-record.json.new"] {
            let local = directory.join(PAYLOAD).join(name);
            let record = record_path(&local);
            assert_eq!(record, directory.join(".hensou-record.json"));
            assert_ne!(record, local);
            assert_ne!(record.with_extension("json.new"), local);
        }
    }
}
