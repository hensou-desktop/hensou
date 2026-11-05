use hensou_files_core::{Config, Files};
use hensou_files_model::{platform::*, *};
use std::{
    path::{Path, PathBuf},
    sync::{Arc, mpsc},
    time::Duration,
};

pub struct Platform;
impl TrashStore for Platform {
    fn delete_kind(&self, _: &Path) -> DeleteKind {
        DeleteKind::Trash
    }
    fn trash(&self, _: &Path) -> Result<PathBuf, FilesError> {
        Err(FilesError::NotFound)
    }
    fn items(&self) -> Result<Vec<TrashItem>, FilesError> {
        Ok(vec![])
    }
    fn restore(&self, _: &Path) -> Result<PathBuf, FilesError> {
        Err(FilesError::NotFound)
    }
    fn empty(&self) -> Result<u64, FilesError> {
        Ok(0)
    }
    fn watch(&self, _: Box<dyn Fn() + Send + Sync>) {}
}
impl VolumeMonitor for Platform {
    fn volumes(&self) -> Vec<Volume> {
        vec![]
    }
    fn eject(&self, _: &str) -> Result<(), FilesError> {
        Ok(())
    }
    fn watch(&self, _: Box<dyn Fn(Vec<Volume>) + Send + Sync>) {}
}
#[allow(dead_code)]
pub fn start(root: &Path) -> (Files, mpsc::Receiver<Event>) {
    let files = Files::new(
        Config::for_home(root),
        Arc::new(Platform),
        Arc::new(Platform),
    )
    .unwrap();
    let (tx, rx) = mpsc::channel();
    files.subscribe(Box::new(move |e| {
        let _ = tx.send(e);
    }));
    (files, rx)
}
pub fn until(rx: &mpsc::Receiver<Event>, predicate: impl Fn(&Event) -> bool) -> Event {
    let deadline = std::time::Instant::now() + Duration::from_secs(30);
    let mut history = vec![];
    loop {
        let e = rx
            .recv_timeout(deadline.saturating_duration_since(std::time::Instant::now()))
            .unwrap_or_else(|e| panic!("{e:?}; received {history:#?}"));
        history.push(e.clone());
        if predicate(&e) {
            return e;
        }
    }
}
