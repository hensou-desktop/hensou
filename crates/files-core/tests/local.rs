use hensou_files_model::*;
use std::{path::PathBuf, sync::mpsc};
mod support;
use support::*;
#[test]
fn lists_metadata_and_broadcasts_to_every_subscriber() {
    let tmp = tempfile::tempdir().unwrap();
    std::fs::write(tmp.path().join(".note"), b"abc").unwrap();
    std::os::unix::fs::symlink(".note", tmp.path().join("alias")).unwrap();
    std::fs::write(
        tmp.path().join("app.desktop"),
        "[Desktop Entry]\nName=Editor\nIcon=editor\n",
    )
    .unwrap();
    let (files, rx) = start(tmp.path());
    let (tx2, rx2) = mpsc::channel();
    files.subscribe(Box::new(move |e| {
        let _ = tx2.send(e);
    }));
    files.send(
        1,
        Command::List {
            location: Location::local(tmp.path()),
        },
    );
    let e = until(&rx, |e| matches!(e, Event::Listing { request: 1, .. }));
    assert_eq!(
        e,
        until(&rx2, |e| matches!(e, Event::Listing { request: 1, .. }))
    );
    let Event::Listing { entries, .. } = e else {
        unreachable!()
    };
    let note = entries.iter().find(|e| e.name == ".note").unwrap();
    assert!(note.hidden);
    assert_eq!(note.size, Some(3));
    assert!(note.mode.is_some());
    let alias = entries.iter().find(|e| e.name == "alias").unwrap();
    assert_eq!(alias.kind, EntryKind::Alias);
    assert_eq!(alias.link_target, Some(".note".into()));
    let app = entries.iter().find(|e| e.name == "app.desktop").unwrap();
    assert_eq!(app.icon.launcher_name.as_deref(), Some("Editor"));
}

#[test]
fn view_memory_survives_service_restart() {
    let tmp = tempfile::tempdir().unwrap();
    let location = Location::local(tmp.path());
    let view = ViewMemory {
        show_hidden: true,
        view: ViewKind::List,
        ..Default::default()
    };
    let (files, rx) = start(tmp.path());
    files.send(
        8,
        Command::SaveView {
            location: location.clone(),
            view: view.clone(),
        },
    );
    until(&rx, |e| matches!(e, Event::Done { request: 8 }));
    drop(files);
    let (files, rx) = start(tmp.path());
    files.send(
        9,
        Command::LoadView {
            location: location.clone(),
        },
    );
    assert_eq!(
        until(&rx, |e| matches!(e, Event::View { request: 9, .. })),
        Event::View {
            request: 9,
            location,
            view
        }
    );
}
#[test]
fn copy_conflict_keep_both_and_alias_copy() {
    let tmp = tempfile::tempdir().unwrap();
    let src = tmp.path().join("src");
    let dst = tmp.path().join("dst");
    std::fs::create_dir(&src).unwrap();
    std::fs::create_dir(&dst).unwrap();
    std::fs::write(src.join("note"), "new").unwrap();
    std::fs::write(dst.join("note"), "old").unwrap();
    std::os::unix::fs::symlink("note", src.join("alias")).unwrap();
    let (files, rx) = start(tmp.path());
    files.send(
        10,
        Command::Transfer {
            mode: TransferMode::Copy,
            sources: vec![
                Location::local(src.join("note")),
                Location::local(src.join("alias")),
            ],
            destination: Location::local(&dst),
        },
    );
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if matches!(transfer.state,TransferState::Conflict { .. })),
    );
    files.send(
        11,
        Command::ResolveConflict {
            id: 10,
            choice: ConflictChoice::KeepBoth,
            apply_to_all: true,
        },
    );
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if transfer.id == 10 && transfer.state == TransferState::Done),
    );
    assert_eq!(std::fs::read_to_string(dst.join("note")).unwrap(), "old");
    assert_eq!(
        std::fs::read_to_string(dst.join("note (copy 1)")).unwrap(),
        "new"
    );
    assert_eq!(
        std::fs::read_link(dst.join("alias")).unwrap(),
        PathBuf::from("note")
    );
}
#[test]
fn watches_folder_and_rejects_path_traversal() {
    let tmp = tempfile::tempdir().unwrap();
    let dir = tmp.path().join("folder");
    std::fs::create_dir(&dir).unwrap();
    let (files, rx) = start(tmp.path());
    files.send(
        1,
        Command::List {
            location: Location::local(&dir),
        },
    );
    until(&rx, |e| matches!(e, Event::Listing { .. }));
    std::fs::write(dir.join("new"), "hello").unwrap();
    until(
        &rx,
        |e| matches!(e,Event::FolderChanged { entries, .. } if entries.iter().any(|e| e.name == "new")),
    );
    files.send(
        2,
        Command::NewFolder {
            parent: Location::local(&dir),
            name: "../escape".into(),
        },
    );
    until(&rx, |e| {
        matches!(
            e,
            Event::Error {
                request: Some(2),
                ..
            }
        )
    });
    assert!(!tmp.path().join("escape").exists());
}
#[test]
fn cancelled_conflict_never_overwrites_destination() {
    let tmp = tempfile::tempdir().unwrap();
    let dst = tmp.path().join("dst");
    std::fs::create_dir(&dst).unwrap();
    std::fs::write(tmp.path().join("note"), "new").unwrap();
    std::fs::write(dst.join("note"), "old").unwrap();
    let (files, rx) = start(tmp.path());
    files.send(
        42,
        Command::Transfer {
            mode: TransferMode::Copy,
            sources: vec![Location::local(tmp.path().join("note"))],
            destination: Location::local(&dst),
        },
    );
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if matches!(transfer.state,TransferState::Conflict { .. })),
    );
    files.send(43, Command::CancelTransfer { id: 42 });
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if transfer.state == TransferState::Cancelled),
    );
    assert_eq!(std::fs::read_to_string(dst.join("note")).unwrap(), "old");
}

#[test]
fn startup_removes_journalled_partial_and_reports_failure() {
    let tmp = tempfile::tempdir().unwrap();
    let state = tmp.path().join(".local/state/hensou/files");
    std::fs::create_dir_all(&state).unwrap();
    let partial = tmp.path().join(".hensou-part-old");
    std::fs::write(&partial, "partial").unwrap();
    let transfer = Transfer {
        id: 90,
        mode: TransferMode::Copy,
        sources: vec![Location::local(tmp.path().join("source"))],
        destination: Location::local(tmp.path()),
        current: None,
        items_done: 0,
        items_total: None,
        bytes_done: 7,
        bytes_total: None,
        state: TransferState::Running,
    };
    std::fs::write(
        state.join("transfer-90.json"),
        serde_json::to_vec(
            &serde_json::json!({"transfer":transfer,"partials":[Location::local(&partial)]}),
        )
        .unwrap(),
    )
    .unwrap();
    let (_files, rx) = start(tmp.path());
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if transfer.id == 90 && matches!(transfer.state,TransferState::Failed { .. })),
    );
    assert!(!partial.exists());
}

#[test]
fn rejects_a_control_socket_path_that_cannot_fit_sun_path() {
    let tmp = tempfile::tempdir().unwrap();
    let mut config = hensou_files_core::Config::for_home(tmp.path());
    config.runtime_dir = tmp.path().join("x".repeat(108));
    let result = hensou_files_core::Files::new(
        config,
        std::sync::Arc::new(Platform),
        std::sync::Arc::new(Platform),
    );
    assert!(matches!(result,Err(FilesError::Other { message }) if message.contains("too long")));
}

#[test]
fn alias_to_directory_uses_the_application_hook() {
    let tmp = tempfile::tempdir().unwrap();
    std::fs::create_dir(tmp.path().join("folder")).unwrap();
    std::os::unix::fs::symlink("folder", tmp.path().join("alias")).unwrap();
    let mut config = hensou_files_core::Config::for_home(tmp.path());
    let (tx, rx) = mpsc::channel();
    config.open_directory = std::sync::Arc::new(move |l| {
        tx.send(l).unwrap();
    });
    let files = hensou_files_core::Files::new(
        config,
        std::sync::Arc::new(Platform),
        std::sync::Arc::new(Platform),
    )
    .unwrap();
    let location = Location::local(tmp.path().join("alias"));
    files.send(
        1,
        Command::Open {
            location: location.clone(),
        },
    );
    assert_eq!(
        rx.recv_timeout(std::time::Duration::from_secs(3)).unwrap(),
        location
    );
}

#[test]
fn refuses_a_directory_copy_through_an_alias_into_itself() {
    let tmp = tempfile::tempdir().unwrap();
    let source = tmp.path().join("folder");
    std::fs::create_dir(&source).unwrap();
    std::os::unix::fs::symlink(&source, tmp.path().join("alias")).unwrap();
    let (files, rx) = start(tmp.path());
    files.send(
        70,
        Command::Transfer {
            mode: TransferMode::Copy,
            sources: vec![Location::local(&source)],
            destination: Location::local(tmp.path().join("alias")),
        },
    );
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if transfer.id == 70 && matches!(transfer.state,TransferState::Failed { .. })),
    );
    assert_eq!(std::fs::read_dir(source).unwrap().count(), 0);
}

#[test]
fn quitting_marks_active_transfers_failed_on_next_start() {
    let tmp = tempfile::tempdir().unwrap();
    let dst = tmp.path().join("dst");
    std::fs::create_dir(&dst).unwrap();
    std::fs::write(tmp.path().join("note"), "new").unwrap();
    std::fs::write(dst.join("note"), "old").unwrap();
    let (files, rx) = start(tmp.path());
    files.send(
        101,
        Command::Transfer {
            mode: TransferMode::Copy,
            sources: vec![Location::local(tmp.path().join("note"))],
            destination: Location::local(&dst),
        },
    );
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if matches!(transfer.state,TransferState::Conflict { .. })),
    );
    drop(files);
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if transfer.id == 101 && matches!(transfer.state,TransferState::Failed { .. })),
    );
    let (_files, rx) = start(tmp.path());
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if transfer.id == 101 && matches!(transfer.state,TransferState::Failed { .. })),
    );
    assert_eq!(std::fs::read_to_string(dst.join("note")).unwrap(), "old");
}
