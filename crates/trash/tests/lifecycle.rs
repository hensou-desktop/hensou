use hensou_files_model::{DeleteKind, platform::TrashStore};
use hensou_trash::FreedesktopTrash;
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
    assert!(matches!(
        store.delete_kind(&original),
        DeleteKind::Permanent { .. }
    ));
}
#[test]
fn restore_does_not_overwrite_and_watcher_sees_external_changes() {
    let dir = tempfile::tempdir().unwrap();
    let store = FreedesktopTrash::new(dir.path().join("Trash"), Vec::new()).unwrap();
    let file = dir.path().join("file");
    std::fs::write(&file, "old").unwrap();
    let stored = store.trash(&file).unwrap();
    std::fs::write(&file, "new").unwrap();
    assert!(store.restore(&stored).is_err());
    assert_eq!(std::fs::read_to_string(&file).unwrap(), "new");
    let (tx, rx) = std::sync::mpsc::channel();
    store.watch(Box::new(move || {
        let _ = tx.send(());
    }));
    std::fs::write(dir.path().join("Trash/files/external"), "x").unwrap();
    rx.recv_timeout(std::time::Duration::from_secs(3)).unwrap();
}
#[test]
fn volume_uses_sticky_shared_trash_and_rejects_symlinks() {
    use std::os::unix::fs::{PermissionsExt, symlink};
    let dir = tempfile::tempdir().unwrap();
    let shared = dir.path().join(".Trash");
    std::fs::create_dir(&shared).unwrap();
    std::fs::set_permissions(&shared, std::fs::Permissions::from_mode(0o1777)).unwrap();
    let root = hensou_trash::volume_trash(dir.path()).unwrap();
    assert!(root.starts_with(&shared));
    let other = tempfile::tempdir().unwrap();
    symlink(&shared, other.path().join(".Trash")).unwrap();
    let root = hensou_trash::volume_trash(other.path()).unwrap();
    assert!(
        root.file_name()
            .unwrap()
            .to_string_lossy()
            .starts_with(".Trash-")
    );
    let unsafe_dir = tempfile::tempdir().unwrap();
    symlink(
        &root,
        unsafe_dir
            .path()
            .join(format!(".Trash-{}", nix::unistd::Uid::current())),
    )
    .unwrap();
    assert!(hensou_trash::volume_trash(unsafe_dir.path()).is_err());
}
#[test]
fn different_filesystem_uses_relative_volume_trashinfo() {
    let home = tempfile::tempdir().unwrap();
    let volume = tempfile::tempdir_in("/dev/shm").unwrap();
    use std::os::unix::fs::MetadataExt;
    assert_ne!(
        std::fs::metadata(home.path()).unwrap().dev(),
        std::fs::metadata(volume.path()).unwrap().dev()
    );
    let store =
        FreedesktopTrash::new(home.path().join("Trash"), vec![volume.path().into()]).unwrap();
    let file = volume.path().join("a b");
    std::fs::write(&file, "data").unwrap();
    let stored = store.trash(&file).unwrap();
    assert!(stored.starts_with(volume.path()));
    let info = stored
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .join("info/a b.trashinfo");
    let text = std::fs::read_to_string(info).unwrap();
    assert!(text.contains("Path=a%20b\n"));
    assert!(text.contains("DeletionDate="));
    assert_eq!(store.items().unwrap()[0].original.path, file);
    assert_eq!(store.restore(&stored).unwrap(), file);
}
#[test]
fn watch_adds_trash_roots_created_after_subscription() {
    let home = tempfile::tempdir().unwrap();
    let volume = tempfile::tempdir().unwrap();
    let store =
        FreedesktopTrash::new(home.path().join("Trash"), vec![volume.path().into()]).unwrap();
    let (tx, rx) = std::sync::mpsc::channel();
    store.watch(Box::new(move || {
        let _ = tx.send(());
    }));
    let root = hensou_trash::volume_trash(volume.path()).unwrap();
    rx.recv_timeout(std::time::Duration::from_secs(4)).unwrap();
    while rx.try_recv().is_ok() {}
    std::fs::write(root.join("files/external"), "data").unwrap();
    rx.recv_timeout(std::time::Duration::from_secs(4)).unwrap();
}
#[test]
fn unsafe_volume_trash_requires_permanent_delete() {
    let home = tempfile::tempdir().unwrap();
    let volume = tempfile::tempdir_in("/dev/shm").unwrap();
    let store =
        FreedesktopTrash::new(home.path().join("Trash"), vec![volume.path().into()]).unwrap();
    let root = volume
        .path()
        .join(format!(".Trash-{}", nix::unistd::Uid::current()));
    std::os::unix::fs::symlink(home.path(), root).unwrap();
    let source = volume.path().join("file");
    std::fs::write(&source, "data").unwrap();
    assert!(matches!(
        store.delete_kind(&source),
        DeleteKind::Permanent { .. }
    ));
    assert!(store.trash(&source).is_err());
    assert_eq!(std::fs::read_to_string(source).unwrap(), "data");
}
