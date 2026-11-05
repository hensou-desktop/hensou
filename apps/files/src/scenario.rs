//! The development and test service: `FakeFiles` plus the states the UI must
//! draw that its fixtures do not reach (a conflict, a host that asks to keep
//! waiting, working copies, a changed host key, Trash contents, a large
//! folder, long and unknown values). It also applies the commands the UI
//! sends, so a window can trash, rename, restore and copy against it.
//!
//! Choose it with `hensou-files --fixture` or `HENSOU_FILES_BACKEND=fixture`.
//! `HENSOU_FILES_FIXTURE=quiet` leaves out the seeded transfers and working
//! copies (only `FakeFiles`' own waiting transfer remains).

use hensou_files_model::fake::FakeFiles;
use hensou_files_model::*;
use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

/// Fixture transfers use ids the app never allocates (it counts up from 1).
pub const FIXTURE_IDS: u64 = 1 << 47;
/// Requests this service sends to `FakeFiles` for its own refreshes.
const INTERNAL_REQUEST: RequestId = 1 << 62;
/// The host whose key changed since it was trusted.
pub const CHANGED_HOST: &str = "nara";
const NOW: i64 = 1_762_300_800;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct ScenarioOptions {
    /// No seeded transfers or working copies.
    pub quiet: bool,
}

impl ScenarioOptions {
    pub fn from_env() -> Self {
        Self {
            quiet: std::env::var("HENSOU_FILES_FIXTURE").is_ok_and(|v| v == "quiet"),
        }
    }
}

type SharedSink = Arc<EventSink>;

pub struct FixtureScenario {
    inner: Arc<dyn FilesService>,
    overlay: Arc<Mutex<Overlay>>,
    sinks: Mutex<Vec<SharedSink>>,
}

#[derive(Default)]
struct Overlay {
    removed: BTreeSet<Location>,
    renamed: BTreeMap<Location, String>,
    /// Entries shown in a folder in addition to the inner service's.
    added: BTreeMap<Location, Vec<Entry>>,
    /// Folders this service lists by itself.
    owned: BTreeMap<Location, Vec<Entry>>,
    trash: Vec<TrashItem>,
    transfers: BTreeMap<TransferId, Transfer>,
    copies: Vec<WorkingCopy>,
    known: BTreeMap<Location, Entry>,
}

fn file(parent: &Location, name: &str, kind: EntryKind, size: Option<u64>, icon: &str) -> Entry {
    Entry {
        location: Location {
            place: parent.place.clone(),
            path: parent.path.join(name),
        },
        name: name.into(),
        kind,
        size,
        modified: Some(NOW),
        hidden: name.starts_with('.'),
        link_target: None,
        owner: Some("simonwjackson".into()),
        mode: Some(if kind == EntryKind::Folder { 0o755 } else { 0o644 }),
        icon: IconHint {
            name: icon.into(),
            launcher_icon: None,
            launcher_name: None,
        },
    }
}

fn parent_of(location: &Location) -> Location {
    Location {
        place: location.place.clone(),
        path: location
            .path
            .parent()
            .map(PathBuf::from)
            .unwrap_or_default(),
    }
}

impl Overlay {
    fn seeded(options: ScenarioOptions) -> Self {
        let mut overlay = Overlay::default();
        let home = Location::local("/home/fixture");
        let stress = Location::local("/home/fixture/Stress");
        let mut readonly = file(&home, "Read-only notes.txt", EntryKind::File, Some(512), "text-plain");
        readonly.mode = Some(0o444);
        let mut script = file(&home, "run-backup.sh", EntryKind::File, Some(1_204), "application-x-shellscript");
        script.mode = Some(0o755);
        let alias = Entry {
            link_target: Some("/home/fixture/Stress".into()),
            ..file(&home, "Stress alias", EntryKind::Alias, None, "folder")
        };
        overlay.added.insert(
            home.clone(),
            vec![
                file(&home, "Stress", EntryKind::Folder, None, "folder"),
                file(
                    &home,
                    "A very long file name that keeps going well past the width of any column in either theme.txt",
                    EntryKind::File,
                    Some(18_000),
                    "text-plain",
                ),
                file(
                    &home,
                    "UnbrokenNameABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz.bin",
                    EntryKind::File,
                    Some(5_000_000_000_000),
                    "application-octet-stream",
                ),
                file(&home, "empty.txt", EntryKind::File, Some(0), "text-plain"),
                file(&home, "disk-image.iso", EntryKind::File, None, "application-x-cd-image"),
                file(&home, ".config", EntryKind::Folder, None, "folder"),
                file(&home, ".bashrc", EntryKind::File, Some(3_771), "text-plain"),
                readonly,
                script,
                alias,
            ],
        );
        let kinds = [
            ("txt", "text-plain", Some(2_048)),
            ("jpg", "image-jpeg", Some(2_400_000)),
            ("mp3", "audio-mpeg", Some(7_100_000)),
            ("mkv", "video-x-matroska", None),
            ("zip", "application-zip", Some(0)),
            ("pdf", "application-pdf", Some(88_000)),
        ];
        let mut many: Vec<Entry> = (1..=150)
            .map(|i| {
                let (ext, icon, size) = kinds[i % kinds.len()];
                if i % 25 == 0 {
                    file(&stress, &format!("Folder {i:03}"), EntryKind::Folder, None, "folder")
                } else {
                    file(&stress, &format!("Item {i:03}.{ext}"), EntryKind::File, size, icon)
                }
            })
            .collect();
        many.push(file(&stress, ".hidden-in-stress", EntryKind::File, Some(1), "text-plain"));
        overlay.owned.insert(stress, many);
        let kaiju = Location::host("kaiju", "/");
        overlay.added.insert(
            kaiju.clone(),
            vec![
                file(&kaiju, "home", EntryKind::Folder, None, "folder"),
                file(&kaiju, "srv", EntryKind::Folder, None, "folder"),
                file(&kaiju, "backups", EntryKind::Folder, None, "folder"),
                file(&kaiju, "kaiju.log", EntryKind::File, Some(12_345), "text-plain"),
            ],
        );
        let fuji = Location::host("fuji", "/");
        overlay.added.insert(
            fuji.clone(),
            vec![
                file(&fuji, "srv", EntryKind::Folder, None, "folder"),
                file(&fuji, "README", EntryKind::File, None, "text-plain"),
            ],
        );
        let trash_root = Location::local("/home/fixture/.local/share/Trash/files");
        overlay.trash = [
            ("/home/fixture/Documents/old report.pdf", Some(120_000), "application-pdf"),
            ("/home/fixture/photo copy.jpg", Some(3_400_000), "image-jpeg"),
            ("/home/fixture/Folder with a long name that was deleted last week", None, "folder"),
        ]
        .into_iter()
        .map(|(path, size, icon)| {
            let original = Location::local(path);
            let name = original.path.file_name().unwrap().to_string_lossy().to_string();
            let kind = if icon == "folder" { EntryKind::Folder } else { EntryKind::File };
            let entry = file(&trash_root, &name, kind, size, icon);
            TrashItem {
                original,
                stored: entry.location.clone(),
                deleted_at: Some(NOW - 86_400),
                entry,
            }
        })
        .collect();
        if !options.quiet {
            overlay.seed_activity();
        }
        overlay
    }

    fn seed_activity(&mut self) {
        let home = Location::local("/home/fixture");
        let usb = Location::local("/run/media/fixture/USB");
        let source = file(&home, "photo.jpg", EntryKind::File, Some(3_400_000), "image-jpeg");
        let mut existing = file(&usb, "photo.jpg", EntryKind::File, Some(3_100_000), "image-jpeg");
        existing.modified = Some(NOW - 30 * 86_400);
        let conflict = Transfer {
            id: FIXTURE_IDS + 1,
            mode: TransferMode::Copy,
            sources: vec![source.location.clone(), Location::local("/home/fixture/notes.txt")],
            destination: usb,
            current: Some(source.location.clone()),
            items_done: 0,
            items_total: Some(2),
            bytes_done: 0,
            bytes_total: Some(3_402_048),
            state: TransferState::Conflict {
                conflict: Box::new(Conflict { source, existing }),
            },
        };
        let ask = Transfer {
            id: FIXTURE_IDS + 2,
            mode: TransferMode::Move,
            sources: vec![Location::local("/home/fixture/Documents/report.pdf")],
            destination: Location::host("kaiju", "/srv"),
            current: Some(Location::local("/home/fixture/Documents/report.pdf")),
            items_done: 0,
            items_total: Some(1),
            bytes_done: 60_000,
            bytes_total: Some(120_000),
            state: TransferState::AskKeepWaiting {
                host: "kaiju".into(),
            },
        };
        for t in [conflict, ask] {
            self.transfers.insert(t.id, t);
        }
        let cache = PathBuf::from("/home/fixture/.cache/hensou/files/working");
        self.copies = vec![
            WorkingCopy {
                remote: Location::host("fuji", "/srv/media/notes.md"),
                local: cache.join("fuji/srv/media/notes.md"),
                last_saved: Some(NOW - 600),
                state: WorkingCopyState::RemoteChanged,
            },
            WorkingCopy {
                remote: Location::host("kaiju", "/home/simon/todo.txt"),
                local: cache.join("kaiju/home/simon/todo.txt"),
                last_saved: Some(NOW - 60),
                state: WorkingCopyState::UploadQueued,
            },
            WorkingCopy {
                remote: Location::host("fuji", "/srv/config.toml"),
                local: cache.join("fuji/srv/config.toml"),
                last_saved: None,
                state: WorkingCopyState::Watching,
            },
        ];
    }

    /// A folder's entries after the commands this service applied.
    fn apply(&mut self, location: &Location, entries: Vec<Entry>) -> Vec<Entry> {
        let mut out: Vec<Entry> = entries
            .into_iter()
            .chain(self.added.get(location).cloned().unwrap_or_default())
            .filter(|e| !self.removed.contains(&e.location))
            .map(|mut e| {
                if let Some(name) = self.renamed.get(&e.location) {
                    e.location.path = parent_of(&e.location).path.join(name);
                    e.name = name.clone();
                }
                e
            })
            .collect();
        if location.place == Place::SshHosts
            && !out.iter().any(|e| e.name == CHANGED_HOST)
        {
            out.push(Entry {
                location: Location::host(CHANGED_HOST, "/"),
                ..file(location, CHANGED_HOST, EntryKind::Host, None, "network-server")
            });
        }
        for e in &out {
            self.known.insert(e.location.clone(), e.clone());
        }
        out
    }

    fn trash_entries(&self) -> Vec<Entry> {
        self.trash.iter().map(|t| t.entry.clone()).collect()
    }
}

/// Rewrites an event from the inner service through the overlay.
fn transform(overlay: &Mutex<Overlay>, event: Event) -> Event {
    let mut o = overlay.lock().unwrap();
    match event {
        Event::Hosts { mut names } => {
            if !names.iter().any(|n| n == CHANGED_HOST) {
                names.push(CHANGED_HOST.into());
            }
            Event::Hosts { names }
        }
        Event::Trash { .. } => Event::Trash {
            items: o.trash.clone(),
        },
        Event::Listing {
            request,
            location,
            entries,
        } => {
            let entries = o.apply(&location, entries);
            Event::Listing {
                request,
                location,
                entries,
            }
        }
        Event::FolderChanged { location, entries } => {
            let entries = o.apply(&location, entries);
            Event::FolderChanged { location, entries }
        }
        Event::Transfer { transfer } => {
            o.transfers.insert(transfer.id, (*transfer).clone());
            Event::Transfer { transfer }
        }
        other => other,
    }
}

impl FixtureScenario {
    pub fn new(inner: Arc<dyn FilesService>, options: ScenarioOptions) -> Self {
        Self {
            inner,
            overlay: Arc::new(Mutex::new(Overlay::seeded(options))),
            sinks: Mutex::new(Vec::new()),
        }
    }

    pub fn with_fixtures(options: ScenarioOptions) -> Self {
        Self::new(Arc::new(FakeFiles::default()), options)
    }

    fn emit(&self, event: Event) {
        let sinks: Vec<SharedSink> = self.sinks.lock().unwrap().clone();
        for sink in sinks {
            sink(event.clone());
        }
    }

    fn update_transfer(&self, id: TransferId, change: impl FnOnce(&mut Transfer)) -> bool {
        let updated = {
            let mut o = self.overlay.lock().unwrap();
            o.transfers.get_mut(&id).map(|t| {
                change(t);
                t.clone()
            })
        };
        match updated {
            Some(t) => {
                self.emit(Event::Transfer {
                    transfer: Box::new(t),
                });
                true
            }
            None => false,
        }
    }

    /// Lists a folder again after a change, through the same path the UI uses.
    fn relist(&self, folder: Location) {
        let owned = {
            let mut o = self.overlay.lock().unwrap();
            o.owned
                .get(&folder)
                .cloned()
                .map(|entries| o.apply(&folder, entries))
        };
        match owned {
            Some(entries) => self.emit(Event::FolderChanged {
                location: folder,
                entries,
            }),
            None => self.inner.send(INTERNAL_REQUEST, Command::List { location: folder }),
        }
    }

    fn emit_trash(&self) {
        let items = self.overlay.lock().unwrap().trash.clone();
        self.emit(Event::Trash { items });
    }

    fn update_copy(&self, remote: &Location, state: Option<WorkingCopyState>) {
        let event = {
            let mut o = self.overlay.lock().unwrap();
            match state {
                Some(state) => o.copies.iter_mut().find(|c| &c.remote == remote).map(|c| {
                    c.state = state;
                    Event::WorkingCopy { copy: c.clone() }
                }),
                None => {
                    o.copies.retain(|c| &c.remote != remote);
                    Some(Event::WorkingCopyRemoved {
                        remote: remote.clone(),
                    })
                }
            }
        };
        if let Some(event) = event {
            self.emit(event);
        }
    }
}

impl FilesService for FixtureScenario {
    fn subscribe(&self, sink: EventSink) {
        let sink: SharedSink = Arc::new(sink);
        let overlay = self.overlay.clone();
        let forward = sink.clone();
        self.inner
            .subscribe(Box::new(move |e| forward(transform(&overlay, e))));
        let (transfers, copies) = {
            let o = self.overlay.lock().unwrap();
            (
                o.transfers
                    .values()
                    .filter(|t| t.id >= FIXTURE_IDS)
                    .cloned()
                    .collect::<Vec<_>>(),
                o.copies.clone(),
            )
        };
        for transfer in transfers {
            sink(Event::Transfer {
                transfer: Box::new(transfer),
            });
        }
        for copy in copies {
            sink(Event::WorkingCopy { copy });
        }
        self.sinks.lock().unwrap().push(sink);
    }

    fn send(&self, request: RequestId, command: Command) {
        let done = Event::Done { request };
        match command {
            Command::List { location } if location.place == Place::Trash => {
                let entries = self.overlay.lock().unwrap().trash_entries();
                self.emit(Event::Listing {
                    request,
                    location,
                    entries,
                });
            }
            Command::List { location }
                if location.place
                    == (Place::Host {
                        name: CHANGED_HOST.into(),
                    }) =>
            {
                self.emit(Event::Connection {
                    host: CHANGED_HOST.into(),
                    state: ConnectionState::HostKeyChanged {
                        fingerprint: "SHA256:changedChangedChangedChangedChanged00000000".into(),
                    },
                });
                self.emit(Event::Error {
                    request: Some(request),
                    error: FilesError::HostKeyRejected {
                        host: CHANGED_HOST.into(),
                    },
                });
            }
            Command::List { location } => {
                let owned = {
                    let mut o = self.overlay.lock().unwrap();
                    o.owned
                        .get(&location)
                        .cloned()
                        .map(|entries| o.apply(&location, entries))
                };
                match owned {
                    Some(entries) => self.emit(Event::Listing {
                        request,
                        location,
                        entries,
                    }),
                    None => self.inner.send(request, Command::List { location }),
                }
            }
            Command::Transfer {
                mode,
                sources,
                destination,
            } => {
                // The request id is the transfer id (contract).
                let transfer = Transfer {
                    id: request,
                    mode,
                    items_total: Some(sources.len() as u64),
                    current: sources.first().cloned(),
                    sources,
                    destination,
                    items_done: 0,
                    bytes_done: 0,
                    bytes_total: None,
                    state: TransferState::Running,
                };
                self.overlay
                    .lock()
                    .unwrap()
                    .transfers
                    .insert(request, transfer.clone());
                self.emit(Event::Transfer {
                    transfer: Box::new(transfer),
                });
            }
            Command::CancelTransfer { id } => {
                if !self.update_transfer(id, |t| t.state = TransferState::Cancelled) {
                    self.inner.send(request, Command::CancelTransfer { id });
                }
            }
            Command::ResolveConflict { id, choice, .. } => {
                self.update_transfer(id, |t| {
                    t.state = match choice {
                        ConflictChoice::Stop => TransferState::Cancelled,
                        _ => TransferState::Running,
                    };
                    if choice == ConflictChoice::Skip {
                        t.items_done += 1;
                    }
                });
            }
            Command::KeepWaiting { id, keep } => {
                self.update_transfer(id, |t| {
                    t.state = if keep {
                        let host = match &t.state {
                            TransferState::AskKeepWaiting { host } => host.clone(),
                            _ => String::new(),
                        };
                        TransferState::WaitingForHost { host, since: NOW }
                    } else {
                        TransferState::Cancelled
                    };
                });
            }
            Command::MoveToTrash { locations } => {
                let parents: BTreeSet<Location> = {
                    let mut o = self.overlay.lock().unwrap();
                    for location in &locations {
                        o.removed.insert(location.clone());
                        let entry = o.known.get(location).cloned();
                        if let Some(entry) = entry {
                            let stored = Location::local(
                                PathBuf::from("/home/fixture/.local/share/Trash/files").join(&entry.name),
                            );
                            o.trash.push(TrashItem {
                                original: location.clone(),
                                stored: stored.clone(),
                                deleted_at: Some(NOW),
                                entry: Entry {
                                    location: stored,
                                    ..entry
                                },
                            });
                        }
                    }
                    locations.iter().map(parent_of).collect()
                };
                self.emit_trash();
                parents.into_iter().for_each(|p| self.relist(p));
                self.emit(done);
            }
            Command::DeletePermanently { locations } => {
                let parents: BTreeSet<Location> = {
                    let mut o = self.overlay.lock().unwrap();
                    for location in &locations {
                        o.removed.insert(location.clone());
                        o.trash.retain(|t| &t.stored != location);
                    }
                    locations.iter().map(parent_of).collect()
                };
                self.emit_trash();
                parents.into_iter().for_each(|p| self.relist(p));
                self.emit(done);
            }
            Command::RestoreFromTrash { items } => {
                let parents: BTreeSet<Location> = {
                    let mut o = self.overlay.lock().unwrap();
                    let restored: Vec<Location> = o
                        .trash
                        .iter()
                        .filter(|t| items.contains(&t.stored))
                        .map(|t| t.original.clone())
                        .collect();
                    o.trash.retain(|t| !items.contains(&t.stored));
                    for location in &restored {
                        o.removed.remove(location);
                    }
                    restored.iter().map(parent_of).collect()
                };
                self.emit_trash();
                parents.into_iter().for_each(|p| self.relist(p));
                self.emit(done);
            }
            Command::EmptyTrash => {
                self.overlay.lock().unwrap().trash.clear();
                self.emit_trash();
                self.emit(Event::Listing {
                    request,
                    location: Location::virtual_place(Place::Trash),
                    entries: Vec::new(),
                });
                self.emit(done);
            }
            Command::Rename { location, new_name } => {
                self.overlay
                    .lock()
                    .unwrap()
                    .renamed
                    .insert(location.clone(), new_name);
                self.relist(parent_of(&location));
                self.emit(done);
            }
            Command::NewFolder { parent, name } => {
                {
                    let mut o = self.overlay.lock().unwrap();
                    let folder = file(&parent, &name, EntryKind::Folder, None, "folder");
                    o.added.entry(parent.clone()).or_default().push(folder);
                }
                self.relist(parent);
                self.emit(done);
            }
            Command::Info { location } => {
                let entry = self.overlay.lock().unwrap().known.get(&location).cloned();
                self.emit(match entry {
                    Some(entry) => Event::Info { request, entry },
                    None => Event::Error {
                        request: Some(request),
                        error: FilesError::NotFound,
                    },
                });
            }
            Command::Prepare { locations } => {
                let remote: Vec<Location> = locations
                    .iter()
                    .filter(|l| matches!(l.place, Place::Host { .. }))
                    .cloned()
                    .collect();
                let cache = PathBuf::from("/tmp/hensou-files-fixture/prepared");
                let paths: Vec<PathBuf> = locations
                    .iter()
                    .map(|l| match &l.place {
                        Place::Host { name } => cache
                            .join(name)
                            .join(l.path.strip_prefix("/").unwrap_or(&l.path)),
                        _ => l.path.clone(),
                    })
                    .collect();
                if !remote.is_empty() {
                    // A download is a normal transfer whose id is the request.
                    let mut transfer = Transfer {
                        id: request,
                        mode: TransferMode::Copy,
                        sources: remote.clone(),
                        destination: Location::local(cache.clone()),
                        current: remote.first().cloned(),
                        items_done: 0,
                        items_total: Some(remote.len() as u64),
                        bytes_done: 0,
                        bytes_total: None,
                        state: TransferState::Running,
                    };
                    self.emit(Event::Transfer {
                        transfer: Box::new(transfer.clone()),
                    });
                    transfer.items_done = remote.len() as u64;
                    transfer.state = TransferState::Done;
                    self.overlay
                        .lock()
                        .unwrap()
                        .transfers
                        .insert(request, transfer.clone());
                    self.emit(Event::Transfer {
                        transfer: Box::new(transfer),
                    });
                }
                self.emit(Event::Prepared { request, paths });
            }
            Command::ResolveRemoteChange { remote, .. } => {
                self.update_copy(&remote, Some(WorkingCopyState::Watching));
                self.emit(done);
            }
            Command::StopWatching { remote } => {
                self.update_copy(&remote, None);
                self.emit(done);
            }
            Command::ListHandlers { location } => self.emit(Event::Handlers {
                request,
                location,
                handlers: vec![
                    Handler {
                        desktop_id: "org.gnome.TextEditor.desktop".into(),
                        name: "Text Editor".into(),
                        icon: None,
                        is_default: true,
                    },
                    Handler {
                        desktop_id: "dev.zed.Zed.desktop".into(),
                        name: "Zed".into(),
                        icon: None,
                        is_default: false,
                    },
                ],
            }),
            Command::RejectHostKey { host } => self.emit(Event::Error {
                request: Some(request),
                error: FilesError::HostKeyRejected { host },
            }),
            other => self.inner.send(request, other),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn watch(service: &FixtureScenario) -> Arc<Mutex<Vec<Event>>> {
        let seen = Arc::new(Mutex::new(Vec::new()));
        let sink = seen.clone();
        service.subscribe(Box::new(move |e| sink.lock().unwrap().push(e)));
        seen
    }

    fn listing(seen: &Mutex<Vec<Event>>, folder: &Location) -> Option<Vec<Entry>> {
        seen.lock().unwrap().iter().rev().find_map(|e| match e {
            Event::Listing {
                location, entries, ..
            }
            | Event::FolderChanged { location, entries } if location == folder => {
                Some(entries.clone())
            }
            _ => None,
        })
    }

    #[test]
    fn subscribing_shows_a_conflict_working_copies_trash_and_the_changed_host() {
        let service = FixtureScenario::with_fixtures(ScenarioOptions::default());
        let seen = watch(&service);
        let events = seen.lock().unwrap();
        assert!(events.iter().any(|e| matches!(e, Event::Transfer { transfer } if matches!(transfer.state, TransferState::Conflict { .. }))));
        assert!(events.iter().any(|e| matches!(e, Event::Transfer { transfer } if matches!(transfer.state, TransferState::AskKeepWaiting { .. }))));
        assert!(events.iter().any(|e| matches!(e, Event::WorkingCopy { copy } if copy.state == WorkingCopyState::RemoteChanged)));
        assert!(events.iter().any(|e| matches!(e, Event::Trash { items } if items.len() == 3)));
        assert!(events.iter().any(|e| matches!(e, Event::Hosts { names } if names.contains(&CHANGED_HOST.to_string()))));
    }

    #[test]
    fn quiet_leaves_out_the_seeded_activity() {
        let service = FixtureScenario::with_fixtures(ScenarioOptions { quiet: true });
        let seen = watch(&service);
        assert!(!seen.lock().unwrap().iter().any(|e| matches!(e, Event::WorkingCopy { .. })));
    }

    #[test]
    fn home_lists_hidden_files_aliases_and_unknown_sizes() {
        let service = FixtureScenario::with_fixtures(ScenarioOptions::default());
        let seen = watch(&service);
        let home = Location::local("/home/fixture");
        service.send(1, Command::List { location: home.clone() });
        let entries = listing(&seen, &home).unwrap();
        assert!(entries.iter().any(|e| e.hidden));
        assert!(entries.iter().any(|e| e.kind == EntryKind::Alias));
        assert!(entries.iter().any(|e| e.size.is_none() && e.kind == EntryKind::File));
        assert!(entries.iter().any(|e| e.size == Some(0)));
    }

    #[test]
    fn trash_then_restore_round_trips_through_listings() {
        let service = FixtureScenario::with_fixtures(ScenarioOptions::default());
        let seen = watch(&service);
        let home = Location::local("/home/fixture");
        let notes = Location::local("/home/fixture/notes.txt");
        service.send(1, Command::List { location: home.clone() });
        service.send(2, Command::MoveToTrash { locations: vec![notes.clone()] });
        assert!(!listing(&seen, &home).unwrap().iter().any(|e| e.location == notes));
        let stored = Location::local("/home/fixture/.local/share/Trash/files/notes.txt");
        service.send(3, Command::RestoreFromTrash { items: vec![stored] });
        assert!(listing(&seen, &home).unwrap().iter().any(|e| e.location == notes));
    }

    #[test]
    fn transfers_and_downloads_use_the_request_id() {
        let service = FixtureScenario::with_fixtures(ScenarioOptions { quiet: true });
        let seen = watch(&service);
        service.send(
            41,
            Command::Prepare {
                locations: vec![Location::host("fuji", "/srv/a.txt")],
            },
        );
        let events = seen.lock().unwrap();
        let ids: Vec<u64> = events
            .iter()
            .filter_map(|e| match e {
                Event::Transfer { transfer } => Some(transfer.id),
                _ => None,
            })
            .collect();
        assert!(ids.contains(&41));
        assert!(matches!(
            events.last(),
            Some(Event::Prepared { request: 41, paths }) if paths[0].ends_with("fuji/srv/a.txt")
        ));
    }

    #[test]
    fn the_changed_host_is_refused_and_never_listed() {
        let service = FixtureScenario::with_fixtures(ScenarioOptions::default());
        let seen = watch(&service);
        service.send(
            5,
            Command::List {
                location: Location::host(CHANGED_HOST, "/"),
            },
        );
        let events = seen.lock().unwrap();
        assert!(events.iter().any(|e| matches!(e, Event::Connection { state: ConnectionState::HostKeyChanged { .. }, .. })));
        assert!(!events.iter().any(|e| matches!(e, Event::Listing { request: 5, .. })));
    }
}
