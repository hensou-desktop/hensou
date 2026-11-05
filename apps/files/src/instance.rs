//! The single-instance handoff on `$XDG_RUNTIME_DIR/hensou/files.sock`.
//!
//! The resident process holds an advisory lock on `files.lock` for its whole
//! life and listens on `files.sock`. A second launch fails to take the lock,
//! writes its requests as JSON lines, waits for `ok` and exits 0. The lock,
//! not the socket, decides who is resident, so a stale socket left by a crash
//! cannot block a new instance and two simultaneous launches cannot both bind.

use crate::cli::Request;
use std::fs::{File, OpenOptions, TryLockError};
use std::io::{self, BufRead, BufReader, Write};
use std::os::unix::fs::{DirBuilderExt, MetadataExt};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

/// `$XDG_RUNTIME_DIR/hensou`, or a private per-user folder in the temporary
/// directory when the session has no runtime directory.
pub fn directory() -> PathBuf {
    match std::env::var_os("XDG_RUNTIME_DIR").filter(|v| !v.is_empty()) {
        Some(runtime) => PathBuf::from(runtime).join("hensou"),
        None => {
            let uid = std::fs::metadata("/proc/self")
                .map(|m| m.uid())
                .unwrap_or(0);
            std::env::temp_dir().join(format!("hensou-{uid}"))
        }
    }
}

pub enum Claim {
    /// This process is resident. Keep the value alive as long as it is.
    Primary(Resident),
    /// A resident process took the requests.
    Forwarded,
}

pub struct Resident {
    _lock: File,
    listener: UnixListener,
}

pub fn claim(directory: &Path, requests: &[Request]) -> io::Result<Claim> {
    std::fs::DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(directory)?;
    let lock = OpenOptions::new()
        .create(true)
        .truncate(false)
        .write(true)
        .open(directory.join("files.lock"))?;
    let socket = directory.join("files.sock");
    match lock.try_lock() {
        Ok(()) => {
            // We are resident; any socket file is a leftover.
            match std::fs::remove_file(&socket) {
                Err(e) if e.kind() != io::ErrorKind::NotFound => return Err(e),
                _ => {}
            }
            let listener = UnixListener::bind(&socket)?;
            Ok(Claim::Primary(Resident {
                _lock: lock,
                listener,
            }))
        }
        Err(TryLockError::WouldBlock) => {
            forward(&socket, requests)?;
            Ok(Claim::Forwarded)
        }
        Err(TryLockError::Error(e)) => Err(e),
    }
}

/// Sends requests to the resident process. The resident may still be
/// starting, so connecting retries for a few seconds.
pub fn forward(socket: &Path, requests: &[Request]) -> io::Result<()> {
    let deadline = Instant::now() + Duration::from_secs(5);
    let mut stream = loop {
        match UnixStream::connect(socket) {
            Ok(stream) => break stream,
            Err(e) if Instant::now() >= deadline => return Err(e),
            Err(_) => std::thread::sleep(Duration::from_millis(50)),
        }
    };
    stream.set_read_timeout(Some(Duration::from_secs(5)))?;
    stream.set_write_timeout(Some(Duration::from_secs(5)))?;
    for request in requests {
        let line = serde_json::to_string(request).map_err(io::Error::other)?;
        writeln!(stream, "{line}")?;
    }
    stream.shutdown(std::net::Shutdown::Write)?;
    let mut reply = String::new();
    BufReader::new(stream).read_line(&mut reply)?;
    if reply.trim() == "ok" {
        Ok(())
    } else {
        Err(io::Error::other(format!(
            "the running Files refused the request: {}",
            reply.trim()
        )))
    }
}

impl Resident {
    /// Accepts handoffs on a background thread for the life of the process.
    pub fn serve(self, deliver: impl Fn(Request) + Send + 'static) {
        std::thread::Builder::new()
            .name("files-handoff".into())
            .spawn(move || {
                let _lock = self._lock;
                for stream in self.listener.incoming().flatten() {
                    if let Err(e) = answer(stream, &deliver) {
                        eprintln!("hensou-files: handoff failed: {e}");
                    }
                }
            })
            .expect("spawn the handoff thread");
    }
}

fn answer(stream: UnixStream, deliver: &impl Fn(Request)) -> io::Result<()> {
    stream.set_read_timeout(Some(Duration::from_secs(5)))?;
    let mut requests = Vec::new();
    for line in BufReader::new(&stream).lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        match serde_json::from_str::<Request>(&line) {
            Ok(request) => requests.push(request),
            Err(e) => {
                writeln!(&stream, "error {e}")?;
                return Ok(());
            }
        }
    }
    for request in requests {
        deliver(request);
    }
    writeln!(&stream, "ok")
}

#[cfg(test)]
mod tests {
    use super::*;
    use hensou_files_model::Location;
    use std::sync::mpsc;

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "hensou-files-instance-{name}-{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&dir);
        dir
    }

    #[test]
    fn second_launch_hands_its_requests_to_the_resident() {
        let dir = scratch("handoff");
        let Claim::Primary(resident) = claim(&dir, &[]).unwrap() else {
            panic!("first claim must be resident");
        };
        let (tx, rx) = mpsc::channel();
        resident.serve(move |r| tx.send(r).unwrap());
        let wanted = vec![
            Request::Open {
                location: Location::local("/home/fixture"),
            },
            Request::Computer,
        ];
        assert!(matches!(claim(&dir, &wanted).unwrap(), Claim::Forwarded));
        let got: Vec<Request> = rx.iter().take(2).collect();
        assert_eq!(got, wanted);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn a_stale_socket_does_not_block_a_new_resident() {
        let dir = scratch("stale");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("files.sock"), b"left by a crash").unwrap();
        assert!(matches!(claim(&dir, &[]).unwrap(), Claim::Primary(_)));
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn the_runtime_folder_is_private() {
        let dir = scratch("mode");
        let _resident = claim(&dir, &[]).unwrap();
        let mode = std::fs::metadata(&dir).unwrap().mode() & 0o777;
        assert_eq!(mode, 0o700);
        let _ = std::fs::remove_dir_all(&dir);
    }
}
