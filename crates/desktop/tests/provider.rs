use hensou_desktop::{Config, DesktopProvider, ProviderHandle};
use hensou_desktop_protocol::*;
use hensou_file_icons::ThemeIcons;
use hensou_files_model::{platform::{TrashStore, VolumeMonitor}, Command, EventSink, FilesError, FilesService, Volume};
use hensou_trash::FreedesktopTrash;
use std::{io::BufReader, os::unix::net::UnixStream, path::Path, sync::{Arc, Mutex}, time::Duration};
#[derive(Default)]
struct Service { commands: Mutex<Vec<(u64, Command)>> }
impl FilesService for Service {
    fn send(&self, request: u64, command: Command) { self.commands.lock().unwrap().push((request, command)); }
    fn subscribe(&self, _: EventSink) {}
}
struct Volumes;
impl VolumeMonitor for Volumes {
    fn volumes(&self) -> Vec<Volume> { vec![Volume { id: "usb".into(), label: "USB".into(), mount_point: Some("/tmp".into()), removable: true, size: Some(42) }] }
    fn eject(&self, _: &str) -> Result<(), FilesError> { Err(FilesError::VolumeBusy { holders: vec!["editor".into()] }) }
    fn watch(&self, _: Box<dyn Fn(Vec<Volume>) + Send + Sync>) {}
}
struct Harness { dir: tempfile::TempDir, service: Arc<Service>, trash: Arc<FreedesktopTrash> }
impl Harness {
    fn new() -> Self { let dir = tempfile::tempdir().unwrap(); let trash = Arc::new(FreedesktopTrash::new(dir.path().join("Trash"), vec![]).unwrap()); Self { dir, service: Arc::default(), trash } }
    fn start(&self) -> ProviderHandle { DesktopProvider::new(self.service.clone(), self.trash.clone(), Arc::new(Volumes), Arc::new(ThemeIcons::new(vec![])), Config { desktop_dir: self.dir.path().join("Desktop"), positions_file: self.dir.path().join("desktop-positions.json"), hostname: "TestHost".into() }).unwrap().serve(self.dir.path().join("desktop.sock")).unwrap() }
    fn client(&self) -> Client { Client::new(&self.dir.path().join("desktop.sock")) }
}
struct Client { input: BufReader<UnixStream>, out: UnixStream }
impl Client {
    fn new(path: &Path) -> Self { let out = UnixStream::connect(path).unwrap(); out.set_read_timeout(Some(Duration::from_secs(5))).unwrap(); let mut client = Self { input: BufReader::new(out.try_clone().unwrap()), out }; client.send(ShellMessage::Hello { major: PROTOCOL_MAJOR, minor: 0 }); assert!(matches!(client.read(), ProviderMessage::Hello { .. })); client }
    fn send(&mut self, m: ShellMessage) { write_line(&mut self.out, &m).unwrap(); }
    fn read(&mut self) -> ProviderMessage { read_line(&mut self.input).unwrap().unwrap() }
    fn subscribe(&mut self, theme: Theme, width: u32) -> (Vec<DesktopIcon>, bool) { self.send(ShellMessage::Subscribe { theme, screen: ScreenLayout { output: "DP-1".into(), width, height: 720, scale: 1.5, usable: Rect { x: 0, y: 24, width, height: 672 } } }); loop { if let ProviderMessage::Snapshot { icons, snap, .. } = self.read() { return (icons, snap); } } }
    fn until(&mut self, predicate: impl Fn(&ProviderMessage) -> bool) -> ProviderMessage { loop { let message = self.read(); if predicate(&message) { return message; } } }
}
#[test]
fn themes_and_version_handshake_over_real_socket() {
    let h = Harness::new(); let _server = h.start();
    std::fs::write(h.dir.path().join("Desktop/notes.txt"), "hello").unwrap(); std::fs::write(h.dir.path().join("Desktop/.hidden"), "secret").unwrap();
    let mut client = h.client();
    let (platinum, snap) = client.subscribe(Theme::Platinum, 1280); assert!(!snap);
    assert_eq!(platinum.iter().map(|i| i.label.as_str()).collect::<Vec<_>>(), ["TestHost", "SSH Hosts", "Trash", "USB", "notes.txt"]);
    let (memphis, _) = client.subscribe(Theme::Memphis, 1280);
    assert_eq!(memphis.iter().map(|i| i.label.as_str()).collect::<Vec<_>>(), ["My Computer", "Network Neighborhood", "Recycle Bin", "notes.txt"]);
    assert_eq!(memphis.iter().find(|i| i.id == "trash").unwrap().full, Some(false));
    let mut wrong = UnixStream::connect(h.dir.path().join("desktop.sock")).unwrap(); write_line(&mut wrong, &ShellMessage::Hello { major: 999, minor: 0 }).unwrap();
    let mut input = BufReader::new(wrong); assert!(matches!(read_line::<ProviderMessage>(&mut input).unwrap(), Some(ProviderMessage::Error { code, .. }) if code == "version")); assert!(read_line::<ProviderMessage>(&mut input).unwrap().is_none());
    drop(client); let mut another = h.client(); assert!(!another.subscribe(Theme::Platinum, 1280).0.is_empty());
}
#[test]
fn positions_restart_recovery_snap_and_arrangement() {
    let h = Harness::new(); let server = h.start(); let mut c = h.client(); c.subscribe(Theme::Platinum, 1280);
    c.send(ShellMessage::Move { moves: vec![("computer".into(), Point { x: 1001, y: 501 })] });
    c.until(|m| matches!(m, ProviderMessage::Changed { upsert, .. } if upsert.iter().any(|i| i.id == "computer" && i.position.x == 1001)));
    drop(c); drop(server);
    let _server = h.start(); let mut c = h.client();
    assert_eq!(c.subscribe(Theme::Platinum, 1280).0[0].position, Point { x: 1001, y: 501 });
    let icons = c.subscribe(Theme::Platinum, 400).0; assert!(icons[0].position.x <= 320); assert_eq!(icons[0].position, Point { x: 320, y: 528 });
    c.send(ShellMessage::SetSnap { snap: true }); c.until(|m| matches!(m, ProviderMessage::Snap { snap: true }));
    c.send(ShellMessage::Move { moves: vec![("computer".into(), Point { x: 177, y: 299 })] });
    c.until(|m| matches!(m, ProviderMessage::Changed { upsert, .. } if upsert.iter().any(|i| i.id == "computer" && i.position == Point { x: 160, y: 312 })));
    c.send(ShellMessage::Arrange { by: ArrangeBy::Name }); c.until(|m| matches!(m, ProviderMessage::Changed { .. }));
    let (icons, snap) = c.subscribe(Theme::Platinum, 400); assert!(snap);
    assert_eq!(icons.iter().find(|i| i.id == "ssh-hosts").unwrap().position, Point { x: 0, y: 24 });
    c.send(ShellMessage::SetSnap { snap: false }); c.until(|m| matches!(m, ProviderMessage::Snap { snap: false }));
    c.send(ShellMessage::Move { moves: vec![("computer".into(), Point { x: 177, y: 299 })] }); c.until(|m| matches!(m, ProviderMessage::Changed { .. }));
    c.send(ShellMessage::Arrange { by: ArrangeBy::CleanUp }); c.until(|m| matches!(m, ProviderMessage::Changed { .. }));
    assert_eq!(c.subscribe(Theme::Platinum, 400).0[0].position, Point { x: 160, y: 312 });
}
#[test]
fn confirmations_actions_and_folder_notifications() {
    let h = Harness::new(); let _server = h.start(); let mut c = h.client(); c.subscribe(Theme::Platinum, 1280);
    let file = h.dir.path().join("Desktop/new.txt"); std::fs::write(&file, "new").unwrap();
    c.until(|m| matches!(m, ProviderMessage::Changed { upsert, .. } if upsert.iter().any(|i| i.id == "file:new.txt")));
    c.send(ShellMessage::CheckTrash { request: 1, ids: vec!["file:new.txt".into()] });
    c.until(|m| matches!(m, ProviderMessage::ConfirmNeeded { request: 1, confirmation: Confirmation::MoveToTrash { count: 1 }, .. }));
    c.send(ShellMessage::CheckEmptyTrash { request: 2 }); c.until(|m| matches!(m, ProviderMessage::ConfirmNeeded { request: 2, confirmation: Confirmation::EmptyTrash { count: 0 }, .. }));
    c.send(ShellMessage::Open { ids: vec!["file:new.txt".into()] });
    // Subscribe is a round-trip barrier after the action.
    c.subscribe(Theme::Platinum, 1280);
    let commands = h.service.commands.lock().unwrap(); assert!(matches!(&commands[0], (id, Command::Open { location }) if *id >= 1 << 48 && location.path == file)); drop(commands);
    c.send(ShellMessage::Eject { id: "volume:usb".into() }); c.until(|m| matches!(m, ProviderMessage::Error { code, .. } if code == "busy"));
    h.trash.trash(&file).unwrap();
    c.until(|m| matches!(m, ProviderMessage::Changed { removed, .. } if removed.contains(&"file:new.txt".into())));
    c.send(ShellMessage::CheckEmptyTrash { request: 3 }); c.until(|m| matches!(m, ProviderMessage::ConfirmNeeded { request: 3, confirmation: Confirmation::EmptyTrash { count: 1 }, .. }));
}
#[test]
fn no_writable_trash_requires_permanent_confirmation() {
    use std::os::unix::fs::PermissionsExt;
    let h = Harness::new(); let _server = h.start();
    std::fs::write(h.dir.path().join("Desktop/no-trash.txt"), "data").unwrap();
    let mut c = h.client(); c.subscribe(Theme::Platinum, 1280);
    std::fs::set_permissions(h.dir.path().join("Trash"), std::fs::Permissions::from_mode(0o755)).unwrap();
    c.send(ShellMessage::CheckTrash { request: 7, ids: vec!["file:no-trash.txt".into()] });
    c.until(|m| matches!(m, ProviderMessage::ConfirmNeeded { request: 7, confirmation: Confirmation::Permanent { count: 1, .. }, .. }));
    std::fs::set_permissions(h.dir.path().join("Trash"), std::fs::Permissions::from_mode(0o700)).unwrap();
}
