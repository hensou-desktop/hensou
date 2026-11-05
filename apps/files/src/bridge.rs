//! The one native object QML talks to. Commands go in as `files-model` JSON;
//! events come out as `files-model` JSON on the Qt thread. The QML store
//! (`qml/Model.js`) owns all view state. This keeps the seam to the service
//! exactly the contract's serde format, with no second schema.

use crate::cli::Request;
use crate::hyprland;
use cxx_qt::{CxxQtThread, Threading};
use cxx_qt_lib::QString;
use hensou_files_model::{Command, FilesService, Geometry};
use std::pin::Pin;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(QString, hostname)]
        #[qproperty(bool, fixture)]
        type FilesBridge = super::FilesBridgeRust;

        /// One `files-model` event as JSON.
        #[qsignal]
        fn received(self: Pin<&mut FilesBridge>, json: QString);

        /// A launch request (`cli::Request` JSON) from a second launch.
        #[qsignal]
        #[cxx_name = "openRequested"]
        fn open_requested(self: Pin<&mut FilesBridge>, json: QString);

        /// Starts receiving events. A new call replaces earlier ones, so a
        /// recreated app root does not receive every event twice.
        #[qinvokable]
        fn subscribe(self: Pin<&mut FilesBridge>);

        /// Sends one `files-model` command (JSON). Returns its request id,
        /// or 0 when the JSON is not a command.
        #[qinvokable]
        fn send(self: &FilesBridge, command: &QString) -> u64;

        /// The launch requests that arrived before QML was ready, as a JSON
        /// array. Later ones arrive through openRequested.
        #[qinvokable]
        #[cxx_name = "takeRequests"]
        fn take_requests(self: Pin<&mut FilesBridge>) -> QString;

        /// True when the compositor can place windows (Hyprland).
        #[qinvokable]
        #[cxx_name = "canPlaceWindows"]
        fn can_place_windows(self: &FilesBridge) -> bool;

        /// Moves and sizes a mapped window (Hyprland), fitted on screen.
        #[qinvokable]
        #[cxx_name = "placeWindow"]
        fn place_window(self: &FilesBridge, title: &QString, geometry: &QString) -> bool;

        /// A window's place as `Geometry` JSON, or "" without Hyprland.
        #[qinvokable]
        #[cxx_name = "windowGeometry"]
        fn window_geometry(self: &FilesBridge, title: &QString) -> QString;
    }

    impl cxx_qt::Threading for FilesBridge {}
}

/// The app's requests count up from 1 and stay below the desktop
/// provider's range, which starts at `1 << 48` (contract).
pub const REQUEST_LIMIT: u64 = 1 << 48;

static SERVICE: OnceLock<Arc<dyn FilesService>> = OnceLock::new();
static NEXT_REQUEST: AtomicU64 = AtomicU64::new(1);
static GENERATION: AtomicU64 = AtomicU64::new(0);
static INBOX: Mutex<Inbox> = Mutex::new(Inbox {
    pending: Vec::new(),
    thread: None,
});

struct Inbox {
    pending: Vec<Request>,
    thread: Option<CxxQtThread<qobject::FilesBridge>>,
}

/// Chooses the service for this process. Call once, before QML loads.
pub fn install(service: Arc<dyn FilesService>) {
    if SERVICE.set(service).is_err() {
        eprintln!("hensou-files: the service was already installed");
    }
}

pub fn service() -> Option<Arc<dyn FilesService>> {
    SERVICE.get().cloned()
}

/// Hands a launch request to the UI, from any thread.
pub fn deliver(request: Request) {
    let mut inbox = INBOX.lock().unwrap();
    match &inbox.thread {
        Some(thread) => {
            let json = serde_json::to_string(&request).unwrap_or_default();
            let queued = thread.queue(move |mut bridge| {
                bridge.as_mut().open_requested(QString::from(json.as_str()));
            });
            if queued.is_err() {
                inbox.thread = None;
                inbox.pending.push(request);
            }
        }
        None => inbox.pending.push(request),
    }
}

/// The next request id. Panics rather than collide with the provider.
pub fn next_request() -> u64 {
    let id = NEXT_REQUEST.fetch_add(1, Ordering::Relaxed);
    assert!(id < REQUEST_LIMIT, "request ids exhausted");
    id
}

/// Parses a command from QML.
pub fn parse_command(json: &str) -> Result<Command, serde_json::Error> {
    serde_json::from_str(json)
}

pub struct FilesBridgeRust {
    hostname: QString,
    fixture: bool,
}

impl Default for FilesBridgeRust {
    fn default() -> Self {
        Self {
            hostname: QString::from(crate::hostname().as_str()),
            fixture: crate::seam::fixture_selected(),
        }
    }
}

impl qobject::FilesBridge {
    pub fn subscribe(self: Pin<&mut Self>) {
        let thread = self.qt_thread();
        INBOX.lock().unwrap().thread = Some(thread.clone());
        let Some(service) = service() else {
            eprintln!("hensou-files: no service installed");
            return;
        };
        let generation = GENERATION.fetch_add(1, Ordering::SeqCst) + 1;
        service.subscribe(Box::new(move |event| {
            if GENERATION.load(Ordering::SeqCst) != generation {
                return;
            }
            let json = match serde_json::to_string(&event) {
                Ok(json) => json,
                Err(e) => {
                    eprintln!("hensou-files: cannot encode an event: {e}");
                    return;
                }
            };
            // Events may arrive on any thread; the UI reads them on its own.
            let _ = thread.queue(move |mut bridge| {
                bridge.as_mut().received(QString::from(json.as_str()));
            });
        }));
    }

    pub fn send(&self, command: &QString) -> u64 {
        let text = command.to_string();
        let command = match parse_command(&text) {
            Ok(command) => command,
            Err(e) => {
                eprintln!("hensou-files: not a command ({e}): {text}");
                return 0;
            }
        };
        let Some(service) = service() else {
            return 0;
        };
        let id = next_request();
        service.send(id, command);
        id
    }

    pub fn take_requests(self: Pin<&mut Self>) -> QString {
        let thread = self.qt_thread();
        let mut inbox = INBOX.lock().unwrap();
        inbox.thread = Some(thread);
        let pending = std::mem::take(&mut inbox.pending);
        QString::from(serde_json::to_string(&pending).unwrap_or_default().as_str())
    }

    pub fn can_place_windows(&self) -> bool {
        hyprland::available()
    }

    pub fn place_window(&self, title: &QString, geometry: &QString) -> bool {
        match serde_json::from_str::<Geometry>(&geometry.to_string()) {
            Ok(geometry) if hyprland::available() => {
                hyprland::place(title.to_string(), geometry);
                true
            }
            _ => false,
        }
    }

    pub fn window_geometry(&self, title: &QString) -> QString {
        hyprland::geometry(&title.to_string())
            .and_then(|g| serde_json::to_string(&g).ok())
            .map(|s| QString::from(s.as_str()))
            .unwrap_or_default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use hensou_files_model::{Location, Place};

    #[test]
    fn qml_commands_use_the_contract_json() {
        let json = r#"{"command":"list","location":{"place":{"type":"host","name":"fuji"},"path":"/srv"}}"#;
        assert_eq!(
            parse_command(json).unwrap(),
            Command::List {
                location: Location::host("fuji", "/srv")
            }
        );
        let json = r#"{"command":"resolve-conflict","id":3,"choice":"keep-both","apply_to_all":true}"#;
        assert!(matches!(
            parse_command(json).unwrap(),
            Command::ResolveConflict { id: 3, apply_to_all: true, .. }
        ));
        let json = r#"{"command":"list","location":{"place":{"type":"computer"},"path":""}}"#;
        assert_eq!(
            parse_command(json).unwrap(),
            Command::List {
                location: Location::virtual_place(Place::Computer)
            }
        );
        assert!(parse_command(r#"{"command":"format-disk"}"#).is_err());
    }

    #[test]
    fn request_ids_count_up_below_the_provider_range() {
        let a = next_request();
        let b = next_request();
        assert!(b > a && a >= 1 && b < REQUEST_LIMIT);
    }
}
