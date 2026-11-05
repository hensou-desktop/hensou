use hensou_desktop::{Config, DesktopProvider, ProviderHandle};
use hensou_desktop_protocol::*;
use hensou_file_icons::ThemeIcons;
use hensou_files_model::{
    Command, EventSink, FilesError, FilesService, Volume,
    platform::{TrashStore, VolumeMonitor},
};
use hensou_trash::FreedesktopTrash;
use std::{
    io::BufReader,
    os::unix::net::UnixStream,
    path::Path,
    sync::{Arc, Mutex},
    time::Duration,
};
#[derive(Default)]
struct Service {
    commands: Mutex<Vec<(u64, Command)>>,
}
impl FilesService for Service {
    fn send(&self, request: u64, command: Command) {
        self.commands.lock().unwrap().push((request, command));
    }
    fn subscribe(&self, _: EventSink) {}
}
struct Volumes;
impl VolumeMonitor for Volumes {
    fn volumes(&self) -> Vec<Volume> {
        vec![Volume {
            id: "usb".into(),
            label: "USB".into(),
            mount_point: Some("/tmp".into()),
            removable: true,
            size: Some(42),
        }]
    }
    fn eject(&self, _: &str) -> Result<(), FilesError> {
        Err(FilesError::VolumeBusy {
            holders: vec!["editor".into()],
        })
    }
    fn watch(&self, _: Box<dyn Fn(Vec<Volume>) + Send + Sync>) {}
}
struct Harness {
    dir: tempfile::TempDir,
    service: Arc<Service>,
    trash: Arc<FreedesktopTrash>,
}
impl Harness {
    fn new() -> Self {
        let dir = tempfile::tempdir().unwrap();
        let trash = Arc::new(FreedesktopTrash::new(dir.path().join("Trash"), vec![]).unwrap());
        Self {
            dir,
            service: Arc::default(),
            trash,
        }
    }
    fn start(&self) -> ProviderHandle {
        DesktopProvider::new(
            self.service.clone(),
            self.trash.clone(),
            Arc::new(Volumes),
            Arc::new(ThemeIcons::new(vec![])),
            Config {
                desktop_dir: self.dir.path().join("Desktop"),
                positions_file: self.dir.path().join("desktop-positions.json"),
                hostname: "TestHost".into(),
            },
        )
        .unwrap()
        .serve(self.dir.path().join("desktop.sock"))
        .unwrap()
    }
    fn client(&self) -> Client {
        Client::new(&self.dir.path().join("desktop.sock"))
    }
}
struct Client {
    input: BufReader<UnixStream>,
    out: UnixStream,
}
impl Client {
    fn new(path: &Path) -> Self {
        let out = UnixStream::connect(path).unwrap();
        out.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
        let mut client = Self {
            input: BufReader::new(out.try_clone().unwrap()),
            out,
        };
        client.send(ShellMessage::Hello {
            major: PROTOCOL_MAJOR,
            minor: 0,
        });
        assert!(matches!(client.read(), ProviderMessage::Hello { .. }));
        client
    }
    fn send(&mut self, m: ShellMessage) {
        write_line(&mut self.out, &m).unwrap();
    }
    fn read(&mut self) -> ProviderMessage {
        read_line(&mut self.input).unwrap().unwrap()
    }
    fn subscribe(&mut self, theme: Theme, width: u32) -> (Vec<DesktopIcon>, bool) {
        self.send(ShellMessage::Subscribe {
            theme,
            screen: ScreenLayout {
                output: "DP-1".into(),
                width,
                height: 720,
                scale: 1.5,
                usable: Rect {
                    x: 0,
                    y: 24,
                    width,
                    height: 672,
                },
            },
        });
        loop {
            if let ProviderMessage::Snapshot { icons, snap, grid } = self.read() {
                assert_eq!(
                    grid,
                    match theme {
                        Theme::Platinum => GridSpec {
                            cell_width: 80,
                            cell_height: 72
                        },
                        Theme::Memphis => GridSpec {
                            cell_width: 100,
                            cell_height: 100
                        },
                    }
                );
                return (icons, snap);
            }
        }
    }
    fn until(&mut self, predicate: impl Fn(&ProviderMessage) -> bool) -> ProviderMessage {
        loop {
            let message = self.read();
            if predicate(&message) {
                return message;
            }
        }
    }
}
#[test]
fn themes_and_version_handshake_over_real_socket() {
    let h = Harness::new();
    let _server = h.start();
    std::fs::write(h.dir.path().join("Desktop/notes.txt"), "hello").unwrap();
    std::fs::write(h.dir.path().join("Desktop/.hidden"), "secret").unwrap();
    let mut client = h.client();
    let (platinum, snap) = client.subscribe(Theme::Platinum, 1280);
    assert!(!snap);
    assert_eq!(
        platinum
            .iter()
            .map(|i| i.label.as_str())
            .collect::<Vec<_>>(),
        ["TestHost", "SSH Hosts", "Trash", "USB", "notes.txt"]
    );
    let (memphis, _) = client.subscribe(Theme::Memphis, 1280);
    assert_eq!(
        memphis.iter().map(|i| i.label.as_str()).collect::<Vec<_>>(),
        [
            "My Computer",
            "Network Neighborhood",
            "Recycle Bin",
            "notes.txt"
        ]
    );
    assert_eq!(
        memphis.iter().find(|i| i.id == "trash").unwrap().full,
        Some(false)
    );
    let mut wrong = UnixStream::connect(h.dir.path().join("desktop.sock")).unwrap();
    write_line(
        &mut wrong,
        &ShellMessage::Hello {
            major: 999,
            minor: 0,
        },
    )
    .unwrap();
    let mut input = BufReader::new(wrong);
    assert!(
        matches!(read_line::<ProviderMessage>(&mut input).unwrap(), Some(ProviderMessage::Error { code, .. }) if code == "version")
    );
    assert!(read_line::<ProviderMessage>(&mut input).unwrap().is_none());
    drop(client);
    let mut another = h.client();
    assert!(!another.subscribe(Theme::Platinum, 1280).0.is_empty());
}
#[test]
fn positions_restart_recovery_snap_and_arrangement() {
    let h = Harness::new();
    let server = h.start();
    let mut c = h.client();
    c.subscribe(Theme::Platinum, 1280);
    c.send(ShellMessage::Move {
        moves: vec![("computer".into(), Point { x: 1001, y: 501 })],
    });
    c.until(|m| matches!(m, ProviderMessage::Changed { upsert, .. } if upsert.iter().any(|i| i.id == "computer" && i.position.x == 1001)));
    drop(c);
    drop(server);
    let _server = h.start();
    let mut c = h.client();
    assert_eq!(
        c.subscribe(Theme::Platinum, 1280).0[0].position,
        Point { x: 1001, y: 501 }
    );
    let icons = c.subscribe(Theme::Platinum, 400).0;
    assert!(icons[0].position.x <= 320);
    assert_eq!(icons[0].position, Point { x: 320, y: 528 });
    c.send(ShellMessage::SetSnap { snap: true });
    c.until(|m| matches!(m, ProviderMessage::Snap { snap: true }));
    c.send(ShellMessage::Move {
        moves: vec![("computer".into(), Point { x: 177, y: 299 })],
    });
    c.until(|m| matches!(m, ProviderMessage::Changed { upsert, .. } if upsert.iter().any(|i| i.id == "computer" && i.position == Point { x: 160, y: 312 })));
    c.send(ShellMessage::Arrange {
        by: ArrangeBy::Name,
    });
    c.until(|m| matches!(m, ProviderMessage::Changed { .. }));
    let (icons, snap) = c.subscribe(Theme::Platinum, 400);
    assert!(snap);
    assert_eq!(
        icons.iter().find(|i| i.id == "ssh-hosts").unwrap().position,
        Point { x: 0, y: 24 }
    );
    c.send(ShellMessage::SetSnap { snap: false });
    c.until(|m| matches!(m, ProviderMessage::Snap { snap: false }));
    c.send(ShellMessage::Move {
        moves: vec![("computer".into(), Point { x: 177, y: 299 })],
    });
    c.until(|m| matches!(m, ProviderMessage::Changed { .. }));
    c.send(ShellMessage::Arrange {
        by: ArrangeBy::CleanUp,
    });
    c.until(|m| matches!(m, ProviderMessage::Changed { .. }));
    assert_eq!(
        c.subscribe(Theme::Platinum, 400).0[0].position,
        Point { x: 160, y: 312 }
    );
}
#[test]
fn confirmations_actions_and_folder_notifications() {
    let h = Harness::new();
    let _server = h.start();
    let mut c = h.client();
    c.subscribe(Theme::Platinum, 1280);
    let file = h.dir.path().join("Desktop/new.txt");
    std::fs::write(&file, "new").unwrap();
    c.until(|m| matches!(m, ProviderMessage::Changed { upsert, .. } if upsert.iter().any(|i| i.id == "file:new.txt")));
    c.send(ShellMessage::CheckTrash {
        request: 1,
        ids: vec!["file:new.txt".into()],
    });
    c.until(|m| {
        matches!(
            m,
            ProviderMessage::ConfirmNeeded {
                request: 1,
                confirmation: Confirmation::MoveToTrash { count: 1 },
                ..
            }
        )
    });
    c.send(ShellMessage::CheckEmptyTrash { request: 2 });
    c.until(|m| {
        matches!(
            m,
            ProviderMessage::ConfirmNeeded {
                request: 2,
                confirmation: Confirmation::EmptyTrash { count: 0 },
                ..
            }
        )
    });
    c.send(ShellMessage::Open {
        ids: vec!["file:new.txt".into()],
    });
    // Subscribe is a round-trip barrier after the action.
    c.subscribe(Theme::Platinum, 1280);
    let commands = h.service.commands.lock().unwrap();
    assert!(
        matches!(&commands[0], (id, Command::Open { location }) if *id >= 1 << 48 && location.path == file)
    );
    drop(commands);
    c.send(ShellMessage::Eject {
        id: "volume:usb".into(),
    });
    c.until(|m| matches!(m, ProviderMessage::Error { code, .. } if code == "busy"));
    h.trash.trash(&file).unwrap();
    c.until(|m| matches!(m, ProviderMessage::Changed { removed, .. } if removed.contains(&"file:new.txt".into())));
    c.send(ShellMessage::CheckEmptyTrash { request: 3 });
    c.until(|m| {
        matches!(
            m,
            ProviderMessage::ConfirmNeeded {
                request: 3,
                confirmation: Confirmation::EmptyTrash { count: 1 },
                ..
            }
        )
    });
}
#[test]
fn no_writable_trash_requires_permanent_confirmation() {
    use std::os::unix::fs::PermissionsExt;
    let h = Harness::new();
    let _server = h.start();
    std::fs::write(h.dir.path().join("Desktop/no-trash.txt"), "data").unwrap();
    let mut c = h.client();
    c.subscribe(Theme::Platinum, 1280);
    std::fs::set_permissions(
        h.dir.path().join("Trash"),
        std::fs::Permissions::from_mode(0o755),
    )
    .unwrap();
    c.send(ShellMessage::CheckTrash {
        request: 7,
        ids: vec!["file:no-trash.txt".into()],
    });
    c.until(|m| {
        matches!(
            m,
            ProviderMessage::ConfirmNeeded {
                request: 7,
                confirmation: Confirmation::Permanent { count: 1, .. },
                ..
            }
        )
    });
    std::fs::set_permissions(
        h.dir.path().join("Trash"),
        std::fs::Permissions::from_mode(0o700),
    )
    .unwrap();
}
#[test]
fn overflow_cascades_without_dropping_icons() {
    let h = Harness::new();
    let _server = h.start();
    for name in ["a", "b", "c", "d", "e", "f"] {
        std::fs::write(h.dir.path().join("Desktop").join(name), "data").unwrap();
    }
    let mut c = h.client();
    c.send(ShellMessage::Subscribe {
        theme: Theme::Memphis,
        screen: ScreenLayout {
            output: "tiny".into(),
            width: 80,
            height: 72,
            scale: 1.0,
            usable: Rect {
                x: 0,
                y: 0,
                width: 80,
                height: 72,
            },
        },
    });
    let ProviderMessage::Snapshot { icons, .. } = c.read() else {
        panic!("expected snapshot");
    };
    assert_eq!(icons.len(), 9);
    assert_eq!(
        icons.iter().map(|i| i.position).collect::<Vec<_>>(),
        [
            Point { x: 0, y: 0 },
            Point { x: 12, y: 12 },
            Point { x: 24, y: 24 },
            Point { x: 36, y: 36 },
            Point { x: 48, y: 48 },
            Point { x: 60, y: 60 },
            Point { x: 6, y: 6 },
            Point { x: 18, y: 18 },
            Point { x: 30, y: 30 }
        ]
    );
}
#[test]
fn actions_route_to_service_with_distinct_provider_request_ids() {
    let h = Harness::new();
    let _server = h.start();
    std::fs::write(h.dir.path().join("Desktop/a.txt"), "data").unwrap();
    std::fs::create_dir(h.dir.path().join("Desktop/Folder")).unwrap();
    let mut c = h.client();
    c.subscribe(Theme::Platinum, 1280);
    let ids = vec!["file:a.txt".to_string()];
    for action in [
        ShellMessage::Rename {
            id: ids[0].clone(),
            name: "renamed.txt".into(),
        },
        ShellMessage::Trash { ids: ids.clone() },
        ShellMessage::DeletePermanently { ids: ids.clone() },
        ShellMessage::Drop {
            ids: ids.clone(),
            target: "file:Folder".into(),
        },
        ShellMessage::Drop {
            ids,
            target: "trash".into(),
        },
        ShellMessage::EmptyTrash,
    ] {
        c.send(action);
    }
    c.subscribe(Theme::Platinum, 1280);
    let commands = h.service.commands.lock().unwrap();
    assert_eq!(commands.len(), 6);
    assert!(commands.windows(2).all(|pair| pair[0].0 < pair[1].0));
    assert!(matches!(commands[0].1, Command::Rename { .. }));
    assert!(matches!(commands[1].1, Command::MoveToTrash { .. }));
    assert!(matches!(commands[2].1, Command::DeletePermanently { .. }));
    assert!(matches!(
        commands[3].1,
        Command::Transfer {
            mode: hensou_files_model::TransferMode::Move,
            ..
        }
    ));
    assert!(matches!(commands[4].1, Command::MoveToTrash { .. }));
    assert!(matches!(commands[5].1, Command::EmptyTrash));
}
#[test]
fn aliases_launchers_and_arrange_sort_metadata() {
    let h = Harness::new();
    let _server = h.start();
    let desktop = h.dir.path().join("Desktop");
    std::fs::write(desktop.join("a.txt"), "longer").unwrap();
    std::fs::write(desktop.join("z.txt"), "x").unwrap();
    std::os::unix::fs::symlink("a.txt", desktop.join("Alias")).unwrap();
    std::fs::write(
        desktop.join("app.desktop"),
        "[Desktop Entry]\nName=Editor\nIcon=editor\n",
    )
    .unwrap();
    let mut c = h.client();
    let (icons, _) = c.subscribe(Theme::Memphis, 1280);
    assert_eq!(
        icons.iter().find(|i| i.id == "file:Alias").unwrap().kind,
        IconKind::Alias
    );
    assert!(matches!(
        icons
            .iter()
            .find(|i| i.id == "file:app.desktop")
            .unwrap()
            .art,
        IconArt::Lettermark { letter: 'E', .. }
    ));
    c.send(ShellMessage::Arrange {
        by: ArrangeBy::Size,
    });
    let (icons, _) = c.subscribe(Theme::Memphis, 1280);
    assert!(
        icons
            .iter()
            .find(|i| i.id == "file:z.txt")
            .unwrap()
            .position
            .y
            < icons
                .iter()
                .find(|i| i.id == "file:a.txt")
                .unwrap()
                .position
                .y
    );
    c.send(ShellMessage::Arrange {
        by: ArrangeBy::Kind,
    });
    let (icons, _) = c.subscribe(Theme::Memphis, 1280);
    assert_eq!(
        icons
            .iter()
            .find(|i| i.id == "file:Alias")
            .unwrap()
            .position,
        Point { x: 0, y: 24 }
    );
    let old = std::time::UNIX_EPOCH + Duration::from_secs(1000);
    let new = std::time::UNIX_EPOCH + Duration::from_secs(2000);
    std::fs::File::open(desktop.join("z.txt"))
        .unwrap()
        .set_modified(old)
        .unwrap();
    std::fs::File::open(desktop.join("a.txt"))
        .unwrap()
        .set_modified(new)
        .unwrap();
    c.send(ShellMessage::Arrange {
        by: ArrangeBy::Date,
    });
    let (icons, _) = c.subscribe(Theme::Memphis, 1280);
    assert!(
        icons
            .iter()
            .find(|i| i.id == "file:z.txt")
            .unwrap()
            .position
            .y
            < icons
                .iter()
                .find(|i| i.id == "file:a.txt")
                .unwrap()
                .position
                .y
    );
}

#[test]
fn theme_switch_preserves_separate_positions_and_starts_fresh() {
    let h = Harness::new();
    let server = h.start();
    let mut c = h.client();
    c.subscribe(Theme::Platinum, 1280);
    let platinum = Point { x: 401, y: 301 };
    c.send(ShellMessage::Move {
        moves: vec![("computer".into(), platinum)],
    });
    assert_eq!(c.subscribe(Theme::Platinum, 1280).0[0].position, platinum);
    let fresh = c.subscribe(Theme::Memphis, 1280).0;
    assert_eq!(
        fresh.iter().map(|i| i.position).collect::<Vec<_>>(),
        [
            Point { x: 0, y: 24 },
            Point { x: 0, y: 124 },
            Point { x: 0, y: 224 }
        ]
    );
    let memphis = Point { x: 1001, y: 501 };
    c.send(ShellMessage::Move {
        moves: vec![("computer".into(), memphis)],
    });
    assert_eq!(c.subscribe(Theme::Memphis, 1280).0[0].position, memphis);
    assert_eq!(c.subscribe(Theme::Platinum, 1280).0[0].position, platinum);
    drop(c);
    drop(server);
    let _server = h.start();
    let mut c = h.client();
    assert_eq!(c.subscribe(Theme::Platinum, 1280).0[0].position, platinum);
    assert_eq!(c.subscribe(Theme::Memphis, 1280).0[0].position, memphis);
    assert_eq!(
        c.subscribe(Theme::Memphis, 400).0[0].position,
        Point { x: 300, y: 524 }
    );
    c.send(ShellMessage::SetSnap { snap: true });
    c.send(ShellMessage::Move {
        moves: vec![("computer".into(), Point { x: 211, y: 333 })],
    });
    assert_eq!(
        c.subscribe(Theme::Memphis, 400).0[0].position,
        Point { x: 200, y: 324 }
    );
    c.send(ShellMessage::Arrange {
        by: ArrangeBy::Name,
    });
    let arranged = c.subscribe(Theme::Memphis, 400).0;
    assert_eq!(
        arranged.iter().map(|i| i.position).collect::<Vec<_>>(),
        [
            Point { x: 0, y: 24 },
            Point { x: 0, y: 124 },
            Point { x: 0, y: 224 }
        ]
    );
    assert_eq!(c.subscribe(Theme::Platinum, 1280).0[0].position, platinum);
}
#[test]
fn memphis_cascade_starts_at_its_last_grid_cell() {
    let h = Harness::new();
    let _server = h.start();
    for name in ["a", "b"] {
        std::fs::write(h.dir.path().join("Desktop").join(name), "data").unwrap();
    }
    let mut c = h.client();
    c.send(ShellMessage::Subscribe {
        theme: Theme::Memphis,
        screen: ScreenLayout {
            output: "small".into(),
            width: 200,
            height: 200,
            scale: 1.5,
            usable: Rect {
                x: 0,
                y: 0,
                width: 200,
                height: 200,
            },
        },
    });
    let ProviderMessage::Snapshot { icons, grid, .. } = c.read() else {
        panic!("expected snapshot");
    };
    assert_eq!(
        grid,
        GridSpec {
            cell_width: 100,
            cell_height: 100
        }
    );
    assert_eq!(
        icons.iter().map(|i| i.position).collect::<Vec<_>>(),
        [
            Point { x: 0, y: 0 },
            Point { x: 0, y: 100 },
            Point { x: 100, y: 0 },
            Point { x: 100, y: 100 },
            Point { x: 112, y: 112 }
        ]
    );
}
