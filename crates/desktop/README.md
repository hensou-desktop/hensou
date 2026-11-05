# Resident desktop provider

Files owns one provider next to its event loop:

```rust,ignore
let provider = DesktopProvider::new(service, trash, volumes, icons, Config::from_env()?)?;
let desktop = provider.serve(hensou_desktop_protocol::socket_path().unwrap())?;
// Keep `desktop` alive. Dropping it closes the listener and connected clients.
```

`new` creates the Desktop folder and loads positions. `serve` binds synchronously,
then accepts clients and watches the folder on its own threads. It does not need
an async runtime. Existing socket paths are not removed: an active resident must
never lose its endpoint. The resident must clean up a stale endpoint after proving
its previous process has stopped.

Request IDs start at `1 << 48`; the app uses the lower range. Service failures
return stable protocol codes to the requesting client. A transfer's request ID is
its transfer ID. Positions and Snap to Grid have one persistent owner, keyed by
output, logical size and scale. Grid dimensions match the protocol reference.

When the grid fills, the coordinator's overflow rule cascades by 12 logical pixels,
then wraps with a 6-pixel inset. All icons remain in the stable snapshot order for
keyboard navigation. The shell owns drawing and confirmations.

## Proof

`tests/provider.rs` uses actual Unix sockets, temporary folders, the real Trash
and icon adapters, and a recording FilesService. It covers both themes, version
refusal, reconnects, folder notifications, actions, confirmations, persistence,
layout recovery, snap, arrange and overflow. No owner's files are used.
