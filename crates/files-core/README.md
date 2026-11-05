# hensou-files-core

`Files::new(Config, Arc<dyn TrashStore>, Arc<dyn VolumeMonitor>)` owns its
command thread, monitoring thread, transfer workers, and a two-thread Tokio
runtime for OpenSSH/SFTP. `send` queues commands without filesystem/network I/O.
Subscribers receive snapshots and then the same event stream. Callbacks run on
a dispatch thread; they must not block and must marshal UI work themselves.

## Composition

- Use `Config::default()` for XDG locations. `Config::for_home(path)` is an
  isolated configuration for tests; override `runtime_dir` if its path is long.
- Set `open_directory` to the application's window-routing hook. Its default
  is a no-op because this crate cannot construct a Files window.
- The default `open_file` invokes `xdg-open`, or `gtk-launch` for Open With.
  Applications and tests can supply an alternative callback.
- Wire the host network-change signal to `Files::network_changed()`. The
  method queues an immediate retry; this crate does not depend on NetworkManager.
- The ID of a Transfer or Prepare request is its TransferId. Request IDs must
  be unique across callers while work is active. An active-ID collision emits
  `Error::Other("duplicate request id")` without starting work. Use a fresh
  request ID for CancelTransfer and pass the original ID in `id`.
- A remote Prepare emits normal transfer progress. Cancel emits Cancelled and
  never emits Prepared. Local-only Prepare returns the existing local paths.
- ControlMaster sockets use `$XDG_RUNTIME_DIR/hensou/ssh`, or
  `/tmp/hensou-ssh-$uid` if XDG_RUNTIME_DIR is unset. The directory must be
  owned by the current user; it is mode 0700. Too-long socket paths are rejected
  before starting threads. Persistent journals and views remain in
  `$XDG_STATE_HOME/hensou/files`.

## Storage and failure behavior

Copies stage into exclusive temporary names, then publish atomically. Local
publication uses no-clobber rename. Remote files use OpenSSH hard-link publication
and unlink the temporary name, because the SFTP library's POSIX rename would
overwrite a racing destination. Explicit replacement uses rename. Moves first attempt
same-place rename; cross-filesystem moves copy through this machine and delete
only after the destination is committed. Local aliases are copied as aliases.
Copy permissions retain ordinary read/write/execute bits, not setuid/setgid.
Conflicts require an explicit choice. Moves remove a source only after its
destination has committed, even if cancellation interrupts later items.
Journals are synchronized before creating partial files. Startup removes their
partials and reports failed transfers, rather than resuming them. An offline
remote partial remains journalled if cleanup cannot reach its host. Cleanup
tries again on reconnect and skips active work. Journal filenames are unique
across service instances, even when request IDs restart at 1.

Working-copy records persist beside the local copy. Local save detection uses
size and nanosecond mtime; remote checks use SFTP's size and second-resolution
mtime. Unsent copies are retained when watching stops. Keep Remote retains the
unsent local file without watching it. Save As Copy follows the new remote name.
There is no password store and no privilege escalation.

Folders and working copies are polled (one second by default). Open remote
folders therefore keep their SSH sessions active. Remote Trash uses the host's
home freedesktop Trash only after comparing filesystem device IDs. It requires
host `mkdir` and `stat` utilities; unavailable or different-filesystem Trash is
reported as Permanent, never silently deleted. Failed cleanup remains visible
through Error or a retained journal.

## Verification

Tests use isolated temporary directories, injected platform implementations,
and an unprivileged loopback sshd with temporary host/user keys. They do not
use the owner's SSH configuration or known_hosts. The sshd SFTP starting
directory is its temporary root. The daemon and sessions use a temporary HOME;
user SSH rc files are disabled. Set `HENSOU_TEST_SSHD` if sshd is not at
`/run/current-system/sw/bin/sshd`. SSH runtime directories use short temporary
paths under `/tmp`, independent of a Nix shell's TMPDIR.

Run only on Aka through the shared heavy-job wrapper:

```
cargo fmt -p hensou-files-core -- --check
cargo test --locked -p hensou-files-core
cargo clippy --locked -p hensou-files-core --all-targets -- -D warnings
```
