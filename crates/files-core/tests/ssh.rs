use hensou_files_core::{Config, Files};
use hensou_files_model::*;
use std::{
    fs,
    net::TcpListener,
    os::unix::process::CommandExt,
    path::PathBuf,
    process::{Child, Command as Process, Stdio},
    sync::{Arc, mpsc},
    time::{Duration, Instant},
};
mod support;
use support::{Platform, until};

struct Server {
    root: tempfile::TempDir,
    runtime: tempfile::TempDir,
    child: Option<Child>,
    port: u16,
}
impl Server {
    fn new() -> Self {
        let root = tempfile::tempdir().unwrap();
        let port = TcpListener::bind("127.0.0.1:0")
            .unwrap()
            .local_addr()
            .unwrap()
            .port();
        let mut server = Self {
            root,
            runtime: tempfile::Builder::new()
                .prefix("hf-")
                .tempdir_in("/tmp")
                .unwrap(),
            child: None,
            port,
        };
        for name in ["host", "user"] {
            assert!(
                Process::new("ssh-keygen")
                    .args(["-q", "-t", "ed25519", "-N", "", "-f"])
                    .arg(server.path(name))
                    .status()
                    .unwrap()
                    .success()
            );
        }
        let user =
            String::from_utf8(Process::new("id").arg("-un").output().unwrap().stdout).unwrap();
        fs::write(server.path("sshd_config"),format!("ListenAddress 127.0.0.1\nPort {port}\nHostKey {}\nPidFile {}\nAuthorizedKeysFile {}\nStrictModes no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nUsePAM no\nPermitRootLogin yes\nAllowUsers {}\nSubsystem sftp internal-sftp -d {}\n",server.path("host").display(),server.path("pid").display(),server.path("user.pub").display(),user.trim(),server.root.path().display())).unwrap();
        fs::create_dir(server.path(".ssh")).unwrap();
        fs::write(server.path(".ssh/config"),format!("Host loopback\n HostName 127.0.0.1\n Port {port}\n User {}\n IdentityFile {}\n IdentitiesOnly yes\n GlobalKnownHostsFile /dev/null\nHost wildcard-*\n HostName nowhere\n",user.trim(),server.path("user").display())).unwrap();
        server.start();
        server
    }
    fn path(&self, p: &str) -> PathBuf {
        self.root.path().join(p)
    }
    fn start(&mut self) {
        let sshd = std::env::var_os("HENSOU_TEST_SSHD")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("/run/current-system/sw/bin/sshd"));
        self.child = Some(
            Process::new(sshd)
                .args(["-D", "-e", "-f"])
                .arg(self.path("sshd_config"))
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(fs::File::create(self.path("sshd.log")).unwrap())
                .process_group(0)
                .spawn()
                .unwrap(),
        );
        let deadline = Instant::now() + Duration::from_secs(5);
        while std::net::TcpStream::connect(("127.0.0.1", self.port)).is_err() {
            assert!(
                Instant::now() < deadline,
                "sshd failed: {}",
                fs::read_to_string(self.path("sshd.log")).unwrap()
            );
            std::thread::sleep(Duration::from_millis(20));
        }
    }
    fn stop(&mut self) {
        if let Some(mut child) = self.child.take() {
            let output = Process::new("ps")
                .args(["-eo", "pid=,ppid="])
                .output()
                .unwrap();
            let pairs: Vec<(u32, u32)> = String::from_utf8_lossy(&output.stdout)
                .lines()
                .filter_map(|line| {
                    let mut fields = line.split_whitespace();
                    Some((fields.next()?.parse().ok()?, fields.next()?.parse().ok()?))
                })
                .collect();
            let mut owned = vec![child.id()];
            loop {
                let more: Vec<_> = pairs
                    .iter()
                    .filter(|(pid, parent)| owned.contains(parent) && !owned.contains(pid))
                    .map(|(pid, _)| *pid)
                    .collect();
                if more.is_empty() {
                    break;
                }
                owned.extend(more);
            }
            for pid in owned.into_iter().rev() {
                let _ = Process::new("kill")
                    .args(["-KILL", "--", &pid.to_string()])
                    .status();
            }
            let _ = child.wait();
        }
    }
    fn files(&self) -> (Files, mpsc::Receiver<Event>) {
        let mut config = Config::for_home(self.root.path());
        config.runtime_dir = self.runtime.path().to_owned();
        config.open_file = Arc::new(|_, _| Ok(()));
        config.poll_interval = Duration::from_millis(100);
        let files = Files::new(config, Arc::new(Platform), Arc::new(Platform)).unwrap();
        let (tx, rx) = mpsc::channel();
        files.subscribe(Box::new(move |e| {
            let _ = tx.send(e);
        }));
        (files, rx)
    }
    fn trust(&self, files: &Files, rx: &mpsc::Receiver<Event>) {
        files.send(
            1,
            Command::Connect {
                host: "loopback".into(),
            },
        );
        let Event::HostKey { prompt } = until(rx, |e| matches!(e, Event::HostKey { .. })) else {
            unreachable!()
        };
        assert!(prompt.fingerprint.starts_with("SHA256:"));
        assert!(!self.path(".ssh/known_hosts").exists());
        files.send(
            2,
            Command::TrustHostKey {
                host: "loopback".into(),
                fingerprint: prompt.fingerprint,
            },
        );
        until(rx, |e| {
            matches!(
                e,
                Event::Connection {
                    state: ConnectionState::Connected,
                    ..
                }
            )
        });
    }
}
impl Drop for Server {
    fn drop(&mut self) {
        self.stop();
    }
}
#[test]
fn unknown_key_trust_remote_listing_and_changed_key_refusal() {
    let mut server = Server::new();
    fs::create_dir(server.path("data")).unwrap();
    fs::write(server.path("data/note"), "hello").unwrap();
    let (files, rx) = server.files();
    server.trust(&files, &rx);
    files.send(
        3,
        Command::List {
            location: Location::host("loopback", server.path("data")),
        },
    );
    let Event::Listing { entries, .. } =
        until(&rx, |e| matches!(e, Event::Listing { request: 3, .. }))
    else {
        unreachable!()
    };
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].size, Some(5));
    drop(files);
    server.stop();
    fs::remove_file(server.path("host")).unwrap();
    fs::remove_file(server.path("host.pub")).unwrap();
    assert!(
        Process::new("ssh-keygen")
            .args(["-q", "-t", "ed25519", "-N", "", "-f"])
            .arg(server.path("host"))
            .status()
            .unwrap()
            .success()
    );
    server.start();
    let (files, rx) = server.files();
    files.send(
        4,
        Command::Connect {
            host: "loopback".into(),
        },
    );
    until(&rx, |e| {
        matches!(
            e,
            Event::Connection {
                state: ConnectionState::HostKeyChanged { .. },
                ..
            }
        )
    });
}
#[test]
fn transfer_recovers_after_isolated_sshd_is_killed() {
    let mut server = Server::new();
    fs::create_dir(server.path("destination")).unwrap();
    let bytes = vec![0x5a; 16 * 1024 * 1024];
    fs::write(server.path("large"), &bytes).unwrap();
    let (files, rx) = server.files();
    server.trust(&files, &rx);
    files.send(
        20,
        Command::Transfer {
            mode: TransferMode::Copy,
            sources: vec![Location::local(server.path("large"))],
            destination: Location::host("loopback", server.path("destination")),
        },
    );
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if transfer.id == 20 && transfer.bytes_done >= 128 * 1024),
    );
    server.stop();
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if matches!(transfer.state,TransferState::WaitingForHost { .. })),
    );
    let partial = fs::read_dir(server.path("destination"))
        .unwrap()
        .next()
        .unwrap()
        .unwrap()
        .path();
    let offset = fs::metadata(&partial).unwrap().len();
    assert!(offset > 0);
    server.start();
    files.network_changed();
    loop {
        let event = until(
            &rx,
            |e| matches!(e,Event::Transfer { transfer } if transfer.id == 20 && matches!(transfer.state,TransferState::Running | TransferState::Done | TransferState::Failed { .. })),
        );
        let Event::Transfer { transfer } = event else {
            unreachable!()
        };
        assert!(
            transfer.bytes_done >= offset,
            "transfer restarted below its verified partial offset"
        );
        assert!(
            !matches!(transfer.state, TransferState::Failed { .. }),
            "{transfer:?}"
        );
        if transfer.state == TransferState::Done {
            break;
        }
    }
    assert_eq!(fs::read(server.path("destination/large")).unwrap(), bytes);
    assert!(!partial.exists());
}
#[test]
fn working_copy_checks_remote_changes_and_queues_offline_uploads() {
    let mut server = Server::new();
    fs::write(server.path("note"), "original").unwrap();
    let remote = Location::host("loopback", server.path("note"));
    let (files, rx) = server.files();
    server.trust(&files, &rx);
    files.send(
        30,
        Command::Open {
            location: remote.clone(),
        },
    );
    let Event::WorkingCopy { copy } = until(
        &rx,
        |e| matches!(e,Event::WorkingCopy { copy } if copy.state == WorkingCopyState::Watching),
    ) else {
        unreachable!()
    };
    fs::write(server.path("note"), "remote changed").unwrap();
    fs::write(&copy.local, "local changed").unwrap();
    until(
        &rx,
        |e| matches!(e,Event::WorkingCopy { copy } if copy.state == WorkingCopyState::RemoteChanged),
    );
    assert_eq!(
        fs::read_to_string(server.path("note")).unwrap(),
        "remote changed"
    );
    files.send(
        31,
        Command::ResolveRemoteChange {
            remote: remote.clone(),
            choice: RemoteChangeChoice::Overwrite,
        },
    );
    until(
        &rx,
        |e| matches!(e,Event::WorkingCopy { copy } if copy.state == WorkingCopyState::Watching),
    );
    assert_eq!(
        fs::read_to_string(server.path("note")).unwrap(),
        "local changed"
    );
    server.stop();
    fs::write(&copy.local, "offline edit").unwrap();
    until(
        &rx,
        |e| matches!(e,Event::WorkingCopy { copy } if copy.state == WorkingCopyState::UploadQueued),
    );
    server.start();
    files.network_changed();
    until(
        &rx,
        |e| matches!(e,Event::WorkingCopy { copy } if copy.state == WorkingCopyState::Watching),
    );
    assert_eq!(
        fs::read_to_string(server.path("note")).unwrap(),
        "offline edit"
    );
}

#[test]
fn remote_trash_is_host_owned_and_restore_does_not_overwrite() {
    let server = Server::new();
    fs::write(server.path("discard"), "saved").unwrap();
    let source = Location::host("loopback", server.path("discard"));
    let (files, rx) = server.files();
    server.trust(&files, &rx);
    files.send(
        50,
        Command::CheckDelete {
            locations: vec![source.clone()],
        },
    );
    let event = until(&rx, |e| matches!(e, Event::DeleteCheck { request: 50, .. }));
    assert_eq!(
        event,
        Event::DeleteCheck {
            request: 50,
            results: vec![(source.clone(), DeleteKind::Trash)]
        }
    );
    files.send(
        51,
        Command::MoveToTrash {
            locations: vec![source.clone()],
        },
    );
    let Event::Trash { items } = until(
        &rx,
        |e| matches!(e,Event::Trash { items } if !items.is_empty()),
    ) else {
        unreachable!()
    };
    assert!(!server.path("discard").exists());
    assert_eq!(items[0].original, source);
    assert_eq!(items[0].entry.name, "discard");
    assert!(
        items[0]
            .stored
            .path
            .starts_with(server.path(".local/share/Trash/files"))
    );
    fs::write(server.path("discard"), "new occupant").unwrap();
    files.send(
        54,
        Command::RestoreFromTrash {
            items: vec![items[0].stored.clone()],
        },
    );
    until(&rx, |e| {
        matches!(
            e,
            Event::Error {
                request: Some(54),
                error: FilesError::AlreadyExists
            }
        )
    });
    assert_eq!(
        fs::read_to_string(server.path("discard")).unwrap(),
        "new occupant"
    );
    fs::remove_file(server.path("discard")).unwrap();
    files.send(
        52,
        Command::RestoreFromTrash {
            items: vec![items[0].stored.clone()],
        },
    );
    until(&rx, |e| matches!(e, Event::Done { request: 52 }));
    assert_eq!(fs::read_to_string(server.path("discard")).unwrap(), "saved");
}
#[test]
fn cancelled_remote_prepare_emits_no_paths() {
    let mut server = Server::new();
    fs::write(server.path("large"), vec![1; 16 * 1024 * 1024]).unwrap();
    let (files, rx) = server.files();
    server.trust(&files, &rx);
    files.send(
        60,
        Command::Prepare {
            locations: vec![Location::host("loopback", server.path("large"))],
        },
    );
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if transfer.id == 60 && transfer.bytes_done > 0),
    );
    server.stop();
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if matches!(transfer.state,TransferState::WaitingForHost { .. })),
    );
    files.send(61, Command::CancelTransfer { id: 60 });
    until(
        &rx,
        |e| matches!(e,Event::Transfer { transfer } if transfer.id == 60 && transfer.state == TransferState::Cancelled),
    );
    assert!(
        !rx.try_iter()
            .any(|e| matches!(e, Event::Prepared { request: 60, .. }))
    );
    let cache = server.path(".local/state/hensou/files/prepared/60");
    assert!(!cache.exists() || fs::read_dir(cache).unwrap().count() == 0);
}

#[test]
fn key_changed_between_scan_and_trust_is_refused() {
    let mut server = Server::new();
    let (files, rx) = server.files();
    files.send(
        80,
        Command::Connect {
            host: "loopback".into(),
        },
    );
    let Event::HostKey { prompt } = until(&rx, |e| matches!(e, Event::HostKey { .. })) else {
        unreachable!()
    };
    server.stop();
    fs::remove_file(server.path("host")).unwrap();
    fs::remove_file(server.path("host.pub")).unwrap();
    assert!(
        Process::new("ssh-keygen")
            .args(["-q", "-t", "ed25519", "-N", "", "-f"])
            .arg(server.path("host"))
            .status()
            .unwrap()
            .success()
    );
    server.start();
    files.send(
        81,
        Command::TrustHostKey {
            host: "loopback".into(),
            fingerprint: prompt.fingerprint,
        },
    );
    until(&rx, |e| {
        matches!(
            e,
            Event::Connection {
                state: ConnectionState::HostKeyChanged { .. },
                ..
            }
        )
    });
    files.send(
        82,
        Command::Connect {
            host: "loopback".into(),
        },
    );
    until(&rx, |e| {
        matches!(
            e,
            Event::Error {
                request: Some(82),
                error: FilesError::HostKeyRejected { .. }
            }
        )
    });
}

#[test]
fn disconnected_host_reconnects_without_a_new_file_command() {
    let mut server = Server::new();
    let (files, rx) = server.files();
    server.trust(&files, &rx);
    server.stop();
    until(&rx, |e| {
        matches!(
            e,
            Event::Connection {
                state: ConnectionState::Reconnecting { .. },
                ..
            }
        )
    });
    server.start();
    files.network_changed();
    until(&rx, |e| {
        matches!(
            e,
            Event::Connection {
                state: ConnectionState::Connected,
                ..
            }
        )
    });
}
