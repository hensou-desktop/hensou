use super::*;
use serde::{Deserialize, Serialize};
use std::{sync::Condvar, time::Instant};

pub(crate) struct Job {
    state: Mutex<Control>,
    changed: Condvar,
}
struct Control {
    cancelled: bool,
    choice: Option<(ConflictChoice, bool)>,
    all: Option<ConflictChoice>,
    wait_since: Instant,
}
impl Job {
    fn new() -> Self {
        Self {
            state: Mutex::new(Control {
                cancelled: false,
                choice: None,
                all: None,
                wait_since: Instant::now(),
            }),
            changed: Condvar::new(),
        }
    }
    pub fn cancel(&self) {
        self.state.lock().unwrap().cancelled = true;
        self.changed.notify_all();
    }
    pub fn resolve(&self, choice: ConflictChoice, all: bool) {
        self.state.lock().unwrap().choice = Some((choice, all));
        self.changed.notify_all();
    }
    pub fn keep_waiting(&self) {
        self.state.lock().unwrap().wait_since = Instant::now();
        self.changed.notify_all();
    }
    fn cancelled(&self, engine: &Engine) -> bool {
        self.state.lock().unwrap().cancelled || engine.stopping.load(Ordering::Relaxed)
    }
    fn pause(&self) {
        let _ = self
            .changed
            .wait_timeout(self.state.lock().unwrap(), Duration::from_millis(200))
            .unwrap();
    }
}
#[derive(Serialize, Deserialize)]
struct Journal {
    transfer: Transfer,
    partials: Vec<Location>,
}
struct Runner<'a> {
    engine: &'a Engine,
    job: &'a Job,
    journal: Journal,
    journal_path: PathBuf,
    serial: u64,
}

pub(crate) fn start(
    engine: &Arc<Engine>,
    id: u64,
    mode: TransferMode,
    sources: Vec<Location>,
    destination: Location,
    prepare: bool,
) -> Result<(), FilesError> {
    local::validate(&destination)?;
    for source in &sources {
        local::validate(source)?;
    }
    let job = Arc::new(Job::new());
    {
        let mut jobs = engine.transfers.lock().unwrap();
        if jobs.contains_key(&id) {
            return Err(other("duplicate request id"));
        }
        jobs.insert(id, job.clone());
    }
    let engine = engine.clone();
    thread::spawn(move || {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let journal_path = engine
            .config
            .state_dir
            .join(format!("transfer-{}-{nonce}-{id}.json", std::process::id()));
        let mut runner = Runner {
            engine: &engine,
            job: &job,
            journal: Journal {
                transfer: Transfer {
                    id,
                    mode,
                    sources: sources.clone(),
                    destination: destination.clone(),
                    current: None,
                    items_done: 0,
                    items_total: None,
                    bytes_done: 0,
                    bytes_total: None,
                    state: TransferState::Running,
                },
                partials: vec![],
            },
            journal_path,
            serial: 0,
        };
        runner.emit();
        let result = (|| {
            runner.persist()?;
            if !runner.retry(|| engine.is_directory(&destination))? {
                return Err(other("transfer destination is not a folder"));
            }
            let mut paths = vec![];
            for source in sources {
                let name = source
                    .path
                    .file_name()
                    .ok_or_else(|| other("cannot transfer root"))?;
                let target = Location {
                    place: destination.place.clone(),
                    path: destination.path.join(name),
                };
                if source == target
                    || (source.place == target.place && target.path.starts_with(&source.path))
                {
                    return Err(other("cannot copy a file onto or inside itself"));
                }
                runner.copy(&source, &target, mode)?;
                paths.push(target.path);
            }
            Ok(paths)
        })();
        let cancelled = job.cancelled(&engine);
        let stopping = engine.stopping.load(Ordering::Relaxed);
        if prepare && (cancelled || result.is_err()) {
            let _ = local::remove(&destination.path);
        }
        runner.journal.transfer.state = if stopping {
            TransferState::Failed {
                reason: "Interrupted by Files exit; this transfer will not resume.".into(),
            }
        } else if cancelled {
            TransferState::Cancelled
        } else {
            match &result {
                Ok(_) => TransferState::Done,
                Err(e) => TransferState::Failed {
                    reason: format!("{e:?}"),
                },
            }
        };
        // Keep journal entries when cleanup cannot reach a host. They are retried
        // on next startup; never pretend an inaccessible partial was removed.
        let remaining: Vec<_> = runner
            .journal
            .partials
            .iter()
            .filter(|l| !matches!(engine.remove(l), Ok(()) | Err(FilesError::NotFound)))
            .cloned()
            .collect();
        runner.journal.partials = remaining;
        if runner.journal.partials.is_empty() && !stopping {
            let _ = fs::remove_file(&runner.journal_path);
        } else {
            let _ = runner.persist();
        }
        runner.emit();
        if prepare
            && !cancelled
            && let Ok(paths) = result
        {
            engine.bus.emit(Event::Prepared { request: id, paths });
        }
        engine.transfers.lock().unwrap().remove(&id);
    });
    Ok(())
}
impl Runner<'_> {
    fn persist(&self) -> Result<(), FilesError> {
        atomic_json(&self.journal_path, &self.journal)
    }
    fn emit(&self) {
        self.engine.bus.emit(Event::Transfer {
            transfer: Box::new(self.journal.transfer.clone()),
        });
    }
    fn retry<T>(
        &mut self,
        mut action: impl FnMut() -> Result<T, FilesError>,
    ) -> Result<T, FilesError> {
        loop {
            if self.job.cancelled(self.engine) {
                return Err(other("cancelled"));
            }
            match action() {
                Err(FilesError::HostUnreachable { host }) => {
                    let mut control = self.job.state.lock().unwrap();
                    if !matches!(
                        self.journal.transfer.state,
                        TransferState::WaitingForHost { .. } | TransferState::AskKeepWaiting { .. }
                    ) {
                        control.wait_since = Instant::now();
                    }
                    self.journal.transfer.state =
                        if control.wait_since.elapsed() >= Duration::from_secs(600) {
                            TransferState::AskKeepWaiting { host }
                        } else {
                            TransferState::WaitingForHost {
                                host,
                                since: now() - control.wait_since.elapsed().as_secs() as i64,
                            }
                        };
                    drop(control);
                    self.emit();
                    self.job.pause();
                }
                result => {
                    if result.is_ok() {
                        self.journal.transfer.state = TransferState::Running;
                    }
                    return result;
                }
            }
        }
    }
    fn conflict(&mut self, source: Entry, existing: Entry) -> Result<ConflictChoice, FilesError> {
        let mut control = self.job.state.lock().unwrap();
        if let Some(choice) = control.all {
            return Ok(choice);
        }
        self.journal.transfer.state = TransferState::Conflict {
            conflict: Box::new(Conflict { source, existing }),
        };
        self.emit();
        loop {
            if control.cancelled || self.engine.stopping.load(Ordering::Relaxed) {
                return Err(other("cancelled"));
            }
            if let Some((choice, all)) = control.choice.take() {
                if all {
                    control.all = Some(choice);
                }
                self.journal.transfer.state = TransferState::Running;
                return Ok(choice);
            }
            control = self
                .job
                .changed
                .wait_timeout(control, Duration::from_millis(200))
                .unwrap()
                .0;
        }
    }
    fn copy(
        &mut self,
        source: &Location,
        target: &Location,
        mode: TransferMode,
    ) -> Result<(), FilesError> {
        let engine = self.engine;
        let source_entry = self.retry(|| engine.info(source))?;
        if source_entry.kind == EntryKind::Folder && source.place == target.place {
            let canonical_source = self.retry(|| engine.canonicalize(source))?;
            let parent = Location {
                place: target.place.clone(),
                path: target
                    .path
                    .parent()
                    .ok_or_else(|| other("target has no parent"))?
                    .to_path_buf(),
            };
            if self
                .retry(|| engine.canonicalize(&parent))?
                .starts_with(canonical_source)
            {
                return Err(other("cannot copy a folder into itself through an alias"));
            }
        }

        self.journal.transfer.current = Some(source.clone());
        self.emit();
        let mut target = target.clone();
        let mut replace = false;
        match self.retry(|| engine.info(&target)) {
            Ok(existing) => match self.conflict(source_entry.clone(), existing)? {
                ConflictChoice::Skip => return Ok(()),
                ConflictChoice::Stop => {
                    self.job.cancel();
                    return Err(other("cancelled"));
                }
                ConflictChoice::Replace => replace = true,
                ConflictChoice::KeepBoth => {
                    let original = target.path.clone();
                    let mut n = 1;
                    loop {
                        target.path = original.with_file_name(format!(
                            "{} (copy {n})",
                            original.file_name().unwrap().to_string_lossy()
                        ));
                        match self.retry(|| engine.info(&target)) {
                            Err(FilesError::NotFound) => break,
                            Ok(_) => n += 1,
                            Err(e) => return Err(e),
                        }
                    }
                }
            },
            Err(FilesError::NotFound) => {}
            Err(e) => return Err(e),
        }
        if mode == TransferMode::Move && source.place == target.place {
            match self.retry(|| engine.rename(source, &target, replace)) {
                Ok(()) => {
                    self.journal.transfer.items_done += 1;
                    self.emit();
                    return Ok(());
                }
                Err(FilesError::Other { .. }) => {}
                Err(e) => return Err(e),
            }
        }
        self.serial += 1;
        let partial = Location {
            place: target.place.clone(),
            path: target.path.with_file_name(format!(
                ".hensou-part-{}-{}-{}",
                std::process::id(),
                self.journal.transfer.id,
                self.serial
            )),
        };
        // The journal reaches disk before a partial is created.
        self.journal.partials.push(partial.clone());
        self.persist()?;
        match source_entry.kind {
            EntryKind::Alias => {
                let link = source_entry
                    .link_target
                    .ok_or_else(|| other("alias target missing"))?;
                self.retry(|| engine.symlink(&link, &partial))?;
            }
            EntryKind::Folder => {
                self.retry(|| engine.mkdir(&partial))?;
                for child in self.retry(|| engine.list(source))? {
                    let child_target = Location {
                        place: partial.place.clone(),
                        path: partial.path.join(
                            child
                                .location
                                .path
                                .file_name()
                                .ok_or_else(|| other("folder child has no filename"))?,
                        ),
                    };
                    self.copy(&child.location, &child_target, TransferMode::Copy)?;
                }
            }
            EntryKind::File | EntryKind::Launcher => self.file(source, &partial, &source_entry)?,
            _ => return Err(other("cannot transfer a virtual entry")),
        }
        if source_entry.kind != EntryKind::Alias {
            self.retry(|| engine.copy_mode(&partial, source_entry.mode))?;
        }
        // Replacing a nonempty directory needs an explicit removal only after
        // its complete replacement is ready. Never merge it silently.
        if replace
            && let Ok(existing) = self.retry(|| engine.info(&target))
            && existing.kind == EntryKind::Folder
        {
            self.retry(|| engine.remove(&target))?;
        }
        self.retry(|| engine.rename(&partial, &target, replace))?;
        self.journal.partials.retain(|l| l != &partial);
        self.persist()?;
        if mode == TransferMode::Move {
            self.retry(|| engine.remove(source))?;
        }
        self.journal.transfer.items_done += 1;
        self.emit();
        Ok(())
    }
    fn file(
        &mut self,
        source: &Location,
        partial: &Location,
        initial: &Entry,
    ) -> Result<(), FilesError> {
        let engine = self.engine;
        let mut baseline = (initial.size, initial.modified);
        let mut offset = 0;
        self.retry(|| engine.write_chunk(partial, 0, &[], true))?;
        loop {
            if self.job.cancelled(engine) {
                return Err(other("cancelled"));
            }
            // Checking before every block also covers a transport reconnect
            // between the read and write calls. Data always passes locally.
            let current = self.retry(|| engine.info(source))?;
            let actual = self.retry(|| engine.info(partial))?.size.unwrap_or(0);
            if baseline != (current.size, current.modified) || actual != offset {
                self.retry(|| engine.remove(partial))?;
                self.retry(|| engine.write_chunk(partial, 0, &[], true))?;
                self.journal.transfer.bytes_done =
                    self.journal.transfer.bytes_done.saturating_sub(offset);
                offset = 0;
                baseline = (current.size, current.modified);
            }
            let bytes = self.retry(|| engine.read_chunk(source, offset))?;
            if bytes.is_empty() {
                // A reconnect may return EOF after the source shrank while
                // read_chunk was waiting. Do not publish the old prefix.
                let current = self.retry(|| engine.info(source))?;
                if (current.size, current.modified) != baseline
                    || current.size.is_some_and(|size| size != offset)
                {
                    continue;
                }
                break;
            }
            // On a lost write acknowledgement retry the same offset, rather
            // than append blindly. The next metadata check verifies its size.
            self.retry(|| engine.write_chunk(partial, offset, &bytes, false))?;
            offset += bytes.len() as u64;
            self.journal.transfer.bytes_done += bytes.len() as u64;
            self.emit();
        }
        Ok(())
    }
}
pub(crate) fn recover(engine: &Engine) {
    let _recovery = engine.recovery.lock().unwrap();
    let Ok(entries) = fs::read_dir(&engine.config.state_dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if !name.starts_with("transfer-") || !name.ends_with(".json") {
            continue;
        }
        let result = (|| {
            let mut journal: Journal =
                serde_json::from_slice(&fs::read(&path).map_err(error)?).map_err(other)?;
            // Reconnect cleanup must not touch this instance's active work.
            if engine
                .transfers
                .lock()
                .unwrap()
                .contains_key(&journal.transfer.id)
            {
                return Ok(());
            }

            let mut remaining = vec![];
            for l in journal.partials {
                if !matches!(engine.remove(&l), Ok(()) | Err(FilesError::NotFound)) {
                    remaining.push(l);
                }
            }
            journal.partials = remaining;
            journal.transfer.state = TransferState::Failed {
                reason: "Interrupted by a previous Files exit; this transfer will not resume."
                    .into(),
            };
            engine.bus.emit(Event::Transfer {
                transfer: Box::new(journal.transfer.clone()),
            });
            if journal.partials.is_empty() {
                fs::remove_file(&path).map_err(error)?;
            } else {
                atomic_json(&path, &journal)?;
            }
            Ok::<_, FilesError>(())
        })();
        if let Err(error) = result {
            engine.bus.emit(Event::Error {
                request: None,
                error,
            });
        }
    }
}
