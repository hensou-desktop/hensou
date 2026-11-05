use hensou_trash::FreedesktopTrash;
use hensou_files_model::{DeleteKind, platform::TrashStore};
#[test]
fn trash_restore_empty_and_missing_check() {
    let dir = tempfile::tempdir().unwrap();
    let store = FreedesktopTrash::new(dir.path().join("Trash"), Vec::new()).unwrap();
    let original = dir.path().join("a % file.txt");
    std::fs::write(&original, "data").unwrap();
    assert_eq!(store.delete_kind(&original), DeleteKind::Trash);
    let stored = store.trash(&original).unwrap();
    assert!(!original.exists());
    let items = store.items().unwrap();
    assert_eq!(items.len(), 1);
    assert_eq!(items[0].original.path, original);
    assert_eq!(store.restore(&stored).unwrap(), original);
    assert_eq!(std::fs::read_to_string(&original).unwrap(), "data");
    store.trash(&original).unwrap();
    assert_eq!(store.empty().unwrap(), 1);
    assert!(store.items().unwrap().is_empty());
    assert!(matches!(store.delete_kind(&original), DeleteKind::Permanent { .. }));
}
#[test]
fn restore_does_not_overwrite_and_watcher_sees_external_changes() {
    let dir = tempfile::tempdir().unwrap();
    let store = FreedesktopTrash::new(dir.path().join("Trash"), Vec::new()).unwrap();
    let file = dir.path().join("file"); std::fs::write(&file, "old").unwrap();
    let stored = store.trash(&file).unwrap(); std::fs::write(&file, "new").unwrap();
    assert!(store.restore(&stored).is_err());
    assert_eq!(std::fs::read_to_string(&file).unwrap(), "new");
    let (tx, rx) = std::sync::mpsc::channel();
    store.watch(Box::new(move || { let _ = tx.send(()); }));
    std::fs::write(dir.path().join("Trash/files/external"), "x").unwrap();
    rx.recv_timeout(std::time::Duration::from_secs(3)).unwrap();
}
#[test]
fn volume_uses_sticky_shared_trash_and_rejects_symlinks() {
    use std::os::unix::fs::{symlink, PermissionsExt};
    let dir = tempfile::tempdir().unwrap(); let shared = dir.path().join(".Trash");
    std::fs::create_dir(&shared).unwrap(); std::fs::set_permissions(&shared, std::fs::Permissions::from_mode(0o1777)).unwrap();
    let root = hensou_trash::volume_trash(dir.path()).unwrap(); assert!(root.starts_with(&shared));
    let other = tempfile::tempdir().unwrap(); symlink(&shared, other.path().join(".Trash")).unwrap();
    let root = hensou_trash::volume_trash(other.path()).unwrap(); assert!(root.file_name().unwrap().to_string_lossy().starts_with(".Trash-"));
    let unsafe_dir = tempfile::tempdir().unwrap(); symlink(&root, unsafe_dir.path().join(format!(".Trash-{}", nix::unistd::Uid::current()))).unwrap();
    assert!(hensou_trash::volume_trash(unsafe_dir.path()).is_err());
}
