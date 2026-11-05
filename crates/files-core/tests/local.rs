use hensou_files_core::{Config, Files};
use hensou_files_model::{*, platform::*};
use std::{path::{Path, PathBuf}, sync::{Arc, mpsc}, time::Duration};

struct Platform;
impl TrashStore for Platform {
    fn delete_kind(&self, _: &Path) -> DeleteKind { DeleteKind::Trash }
    fn trash(&self, _: &Path) -> Result<PathBuf, FilesError> { Err(FilesError::NotFound) }
    fn items(&self) -> Result<Vec<TrashItem>, FilesError> { Ok(vec![]) }
    fn restore(&self, _: &Path) -> Result<PathBuf, FilesError> { Err(FilesError::NotFound) }
    fn empty(&self) -> Result<u64, FilesError> { Ok(0) }
    fn watch(&self, _: Box<dyn Fn() + Send + Sync>) {}
}
impl VolumeMonitor for Platform {
    fn volumes(&self) -> Vec<Volume> { vec![] }
    fn eject(&self, _: &str) -> Result<(), FilesError> { Ok(()) }
    fn watch(&self, _: Box<dyn Fn(Vec<Volume>) + Send + Sync>) {}
}
fn start(root: &Path) -> (Files, mpsc::Receiver<Event>) {
    let files = Files::new(Config::for_home(root), Arc::new(Platform), Arc::new(Platform)).unwrap();
    let (tx, rx) = mpsc::channel();
    files.subscribe(Box::new(move |e| { let _ = tx.send(e); }));
    (files, rx)
}
fn until(rx: &mpsc::Receiver<Event>, predicate: impl Fn(&Event) -> bool) -> Event {
    loop { let e = rx.recv_timeout(Duration::from_secs(10)).unwrap(); if predicate(&e) { return e; } }
}
#[test]
fn lists_metadata_and_broadcasts_to_every_subscriber() {
    let tmp = tempfile::tempdir().unwrap();
    std::fs::write(tmp.path().join(".note"), b"abc").unwrap();
    std::os::unix::fs::symlink(".note", tmp.path().join("alias")).unwrap();
    std::fs::write(tmp.path().join("app.desktop"), "[Desktop Entry]\nName=Editor\nIcon=editor\n").unwrap();
    let (files, rx) = start(tmp.path());
    let (tx2, rx2) = mpsc::channel();
    files.subscribe(Box::new(move |e| { let _ = tx2.send(e); }));
    files.send(1, Command::List { location: Location::local(tmp.path()) });
    let e = until(&rx, |e| matches!(e, Event::Listing { request: 1, .. }));
    assert_eq!(e, until(&rx2, |e| matches!(e, Event::Listing { request: 1, .. })));
    let Event::Listing { entries, .. } = e else { unreachable!() };
    let note = entries.iter().find(|e| e.name == ".note").unwrap();
    assert!(note.hidden); assert_eq!(note.size, Some(3)); assert!(note.mode.is_some());
    let alias = entries.iter().find(|e| e.name == "alias").unwrap();
    assert_eq!(alias.kind, EntryKind::Alias); assert_eq!(alias.link_target, Some(".note".into()));
    let app = entries.iter().find(|e| e.name == "app.desktop").unwrap();
    assert_eq!(app.icon.launcher_name.as_deref(), Some("Editor"));
}
