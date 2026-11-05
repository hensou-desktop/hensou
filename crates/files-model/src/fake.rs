//! An in-memory [`FilesService`] with fixture data, for UI work and tests.
//! It answers synchronously on the caller's thread. Fixture host `fuji`
//! starts with an unknown host key; host `kaiju` is reconnecting.

use crate::*;
use std::collections::BTreeMap;
use std::sync::Mutex;

pub struct FakeFiles {
    state: Mutex<State>,
    sinks: Mutex<Vec<EventSink>>,
}

struct State {
    tree: BTreeMap<Location, Vec<Entry>>,
    trusted: Vec<String>,
    transfers: Vec<Transfer>,
    views: BTreeMap<String, ViewMemory>,
    next_transfer: TransferId,
}

fn icon(name: &str) -> IconHint {
    IconHint {
        name: name.into(),
        launcher_icon: None,
    }
}

fn entry(parent: &Location, name: &str, kind: EntryKind, size: Option<u64>, mime: &str) -> Entry {
    Entry {
        location: Location {
            place: parent.place.clone(),
            path: parent.path.join(name),
        },
        name: name.into(),
        kind,
        size,
        modified: Some(1_762_300_800),
        hidden: name.starts_with('.'),
        link_target: None,
        owner: Some("simonwjackson".into()),
        mode: Some(if kind == EntryKind::Folder {
            0o755
        } else {
            0o644
        }),
        icon: icon(mime),
    }
}

impl Default for FakeFiles {
    fn default() -> Self {
        let home = Location::local("/home/fixture");
        let docs = Location::local("/home/fixture/Documents");
        let fuji = Location::host("fuji", "/srv");
        let mut tree = BTreeMap::new();
        tree.insert(
            home.clone(),
            vec![
                entry(&home, "Desktop", EntryKind::Folder, None, "folder"),
                entry(&home, "Documents", EntryKind::Folder, None, "folder"),
                entry(
                    &home,
                    "notes.txt",
                    EntryKind::File,
                    Some(2_048),
                    "text-plain",
                ),
                entry(
                    &home,
                    "photo.jpg",
                    EntryKind::File,
                    Some(3_400_000),
                    "image-jpeg",
                ),
                entry(&home, ".profile", EntryKind::File, Some(220), "text-plain"),
                Entry {
                    link_target: Some("/home/fixture/Documents".into()),
                    ..entry(&home, "Docs link", EntryKind::Alias, None, "folder")
                },
            ],
        );
        tree.insert(
            docs.clone(),
            vec![
                entry(
                    &docs,
                    "report.pdf",
                    EntryKind::File,
                    Some(120_000),
                    "application-pdf",
                ),
                entry(
                    &docs,
                    "archive.tar.gz",
                    EntryKind::File,
                    Some(9_000_000),
                    "application-gzip",
                ),
            ],
        );
        tree.insert(
            fuji.clone(),
            vec![entry(&fuji, "media", EntryKind::Folder, None, "folder")],
        );
        let transfer = Transfer {
            id: 1,
            mode: TransferMode::Copy,
            sources: vec![Location::local("/home/fixture/Documents/archive.tar.gz")],
            destination: Location::host("kaiju", "/tmp"),
            current: Some(Location::local("/home/fixture/Documents/archive.tar.gz")),
            items_done: 0,
            items_total: Some(1),
            bytes_done: 4_000_000,
            bytes_total: Some(9_000_000),
            state: TransferState::WaitingForHost {
                host: "kaiju".into(),
                since: 1_762_300_800,
            },
        };
        Self {
            state: Mutex::new(State {
                tree,
                trusted: vec!["kaiju".into()],
                transfers: vec![transfer],
                views: BTreeMap::new(),
                next_transfer: 2,
            }),
            sinks: Mutex::new(Vec::new()),
        }
    }
}

impl FakeFiles {
    fn emit(&self, event: Event) {
        for sink in self.sinks.lock().unwrap().iter() {
            sink(event.clone());
        }
    }

    fn virtual_entries(&self, place: &Place) -> Vec<Entry> {
        let root = Location::virtual_place(place.clone());
        match place {
            Place::Computer => vec![
                Entry {
                    location: Location::local("/home/fixture"),
                    ..entry(&root, "Home", EntryKind::Folder, None, "user-home")
                },
                Entry {
                    location: Location::local("/run/media/fixture/USB"),
                    ..entry(
                        &root,
                        "USB",
                        EntryKind::Volume,
                        Some(16_000_000_000),
                        "drive-removable-media",
                    )
                },
                Entry {
                    location: Location::virtual_place(Place::SshHosts),
                    ..entry(
                        &root,
                        "SSH Hosts",
                        EntryKind::SshHosts,
                        None,
                        "network-workgroup",
                    )
                },
                Entry {
                    location: Location::virtual_place(Place::Trash),
                    ..entry(&root, "Trash", EntryKind::Trash, None, "user-trash")
                },
            ],
            Place::SshHosts => ["fuji", "kaiju"]
                .iter()
                .map(|h| Entry {
                    location: Location::host(*h, "/"),
                    ..entry(&root, h, EntryKind::Host, None, "network-server")
                })
                .collect(),
            _ => Vec::new(),
        }
    }
}

impl FilesService for FakeFiles {
    fn subscribe(&self, sink: EventSink) {
        let state = self.state.lock().unwrap();
        sink(Event::Hosts {
            names: vec!["fuji".into(), "kaiju".into()],
        });
        sink(Event::Connection {
            host: "kaiju".into(),
            state: ConnectionState::Reconnecting {
                since: 1_762_300_800,
                attempt: 3,
            },
        });
        sink(Event::Volumes {
            volumes: vec![Volume {
                id: "/org/freedesktop/UDisks2/block_devices/sdb1".into(),
                label: "USB".into(),
                mount_point: Some("/run/media/fixture/USB".into()),
                removable: true,
                size: Some(16_000_000_000),
            }],
        });
        sink(Event::Trash { items: Vec::new() });
        for transfer in &state.transfers {
            sink(Event::Transfer {
                transfer: Box::new(transfer.clone()),
            });
        }
        drop(state);
        self.sinks.lock().unwrap().push(sink);
    }

    fn send(&self, request: RequestId, command: Command) {
        match command {
            Command::List { location } => {
                if let Place::Host { name } = &location.place {
                    let trusted = self.state.lock().unwrap().trusted.contains(name);
                    if !trusted {
                        self.emit(Event::HostKey {
                            prompt: HostKeyPrompt {
                                host: name.clone(),
                                algorithm: "ssh-ed25519".into(),
                                fingerprint: "SHA256:fixtureFixtureFixtureFixtureFixture0000000"
                                    .into(),
                            },
                        });
                        return;
                    }
                }
                let entries = match &location.place {
                    Place::Computer | Place::SshHosts => self.virtual_entries(&location.place),
                    _ => self
                        .state
                        .lock()
                        .unwrap()
                        .tree
                        .get(&location)
                        .cloned()
                        .unwrap_or_default(),
                };
                self.emit(Event::Listing {
                    request,
                    location,
                    entries,
                });
            }
            Command::TrustHostKey { host, .. } => {
                self.state.lock().unwrap().trusted.push(host.clone());
                self.emit(Event::Connection {
                    host,
                    state: ConnectionState::Connected,
                });
                self.emit(Event::Done { request });
            }
            Command::CheckDelete { locations } => {
                let results = locations
                    .into_iter()
                    .map(|l| {
                        let kind = if l.path.starts_with("/run/media") {
                            DeleteKind::Permanent {
                                reason: "This volume has no Trash.".into(),
                            }
                        } else {
                            DeleteKind::Trash
                        };
                        (l, kind)
                    })
                    .collect();
                self.emit(Event::DeleteCheck { request, results });
            }
            Command::Transfer {
                mode,
                sources,
                destination,
            } => {
                let mut state = self.state.lock().unwrap();
                let id = state.next_transfer;
                state.next_transfer += 1;
                let transfer = Transfer {
                    id,
                    mode,
                    sources,
                    destination,
                    current: None,
                    items_done: 0,
                    items_total: None,
                    bytes_done: 0,
                    bytes_total: None,
                    state: TransferState::Running,
                };
                state.transfers.push(transfer.clone());
                drop(state);
                self.emit(Event::Transfer {
                    transfer: Box::new(transfer),
                });
            }
            Command::LoadView { location } => {
                let key = format!("{location:?}");
                let view = self
                    .state
                    .lock()
                    .unwrap()
                    .views
                    .get(&key)
                    .cloned()
                    .unwrap_or_default();
                self.emit(Event::View {
                    request,
                    location,
                    view,
                });
            }
            Command::SaveView { location, view } => {
                self.state
                    .lock()
                    .unwrap()
                    .views
                    .insert(format!("{location:?}"), view);
                self.emit(Event::Done { request });
            }
            Command::Eject { .. } => self.emit(Event::Error {
                request: Some(request),
                error: FilesError::VolumeBusy {
                    holders: vec!["ghostty".into()],
                },
            }),
            _ => self.emit(Event::Done { request }),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    fn collect(service: &FakeFiles) -> Arc<Mutex<Vec<Event>>> {
        let seen = Arc::new(Mutex::new(Vec::new()));
        let sink = seen.clone();
        service.subscribe(Box::new(move |e| sink.lock().unwrap().push(e)));
        seen
    }

    #[test]
    fn unknown_host_asks_for_trust_before_listing() {
        let service = FakeFiles::default();
        let seen = collect(&service);
        service.send(
            1,
            Command::List {
                location: Location::host("fuji", "/srv"),
            },
        );
        assert!(matches!(
            seen.lock().unwrap().last(),
            Some(Event::HostKey { .. })
        ));
        service.send(
            2,
            Command::TrustHostKey {
                host: "fuji".into(),
                fingerprint: String::new(),
            },
        );
        service.send(
            3,
            Command::List {
                location: Location::host("fuji", "/srv"),
            },
        );
        assert!(matches!(
            seen.lock().unwrap().last(),
            Some(Event::Listing { request: 3, entries, .. }) if entries.len() == 1
        ));
    }

    #[test]
    fn commands_and_events_round_trip_as_json() {
        let command = Command::Transfer {
            mode: TransferMode::Move,
            sources: vec![Location::local("/a")],
            destination: Location::host("fuji", "/b"),
        };
        let json = serde_json::to_string(&command).unwrap();
        assert_eq!(serde_json::from_str::<Command>(&json).unwrap(), command);
    }
}
