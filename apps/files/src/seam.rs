//! The composition root: the choice of `FilesService`, the shared Trash and
//! volume monitor, and the embedded desktop provider.
//!
//! ```text
//!   hensou-files ──► seam::start(fixture) ──► Arc<dyn FilesService>
//!                         │                        │
//!                         │                        ├─► bridge::install (QML)
//!                         │                        └─► desktop provider
//!                         └─ fixture: FixtureScenario(FakeFiles)
//!                            real:    hensou_files_core
//! ```

use crate::bridge;
use crate::cli::Request;
use crate::scenario::{FixtureScenario, ScenarioOptions};
use hensou_files_model::platform::{TrashStore, VolumeMonitor};
use hensou_files_model::{DeleteKind, FilesError, FilesService, TrashItem, Volume};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock};

static FIXTURE: AtomicBool = AtomicBool::new(false);

/// `--fixture` or `HENSOU_FILES_BACKEND=fixture`.
pub fn wants_fixture(flag: bool) -> bool {
    flag || std::env::var("HENSOU_FILES_BACKEND").is_ok_and(|v| v == "fixture")
}

pub fn fixture_selected() -> bool {
    FIXTURE.load(Ordering::Relaxed)
}

/// Builds the service, installs it for QML and starts what shares it.
pub fn start(fixture: bool) -> Arc<dyn FilesService> {
    let platform = Platform::from_env();
    let service = choose(fixture, &platform);
    bridge::install(service.clone());
    start_desktop_provider(service.clone(), &platform);
    service
}

/// One Trash and one volume monitor for the whole process: the backend and
/// the desktop provider share them, so they agree on what they show.
struct Platform {
    trash: Arc<dyn TrashStore>,
    volumes: Arc<dyn VolumeMonitor>,
}

impl Platform {
    fn from_env() -> Self {
        let trash: Arc<dyn TrashStore> = match hensou_trash::FreedesktopTrash::from_env() {
            Ok(trash) => Arc::new(trash),
            Err(error) => {
                eprintln!("hensou-files: the Trash is unavailable: {error:?}");
                Arc::new(NoTrash)
            }
        };
        let volumes: Arc<dyn VolumeMonitor> = match hensou_volumes::UdisksVolumes::connect() {
            Ok(volumes) => Arc::new(volumes),
            Err(error) => {
                eprintln!("hensou-files: udisks2 is unavailable; no volumes: {error:?}");
                Arc::new(NoVolumes)
            }
        };
        Self { trash, volumes }
    }
}

fn choose(fixture: bool, platform: &Platform) -> Arc<dyn FilesService> {
    if fixture {
        FIXTURE.store(true, Ordering::Relaxed);
        return Arc::new(FixtureScenario::with_fixtures(ScenarioOptions::from_env()));
    }
    let config = hensou_files_core::Config {
        // Core asks Files to open a folder window (for example from a desktop
        // icon). It reaches the UI like a second launch.
        open_directory: Arc::new(|location| bridge::deliver(Request::Open { location })),
        ..hensou_files_core::Config::default()
    };
    match hensou_files_core::Files::new(config, platform.trash.clone(), platform.volumes.clone()) {
        Ok(files) => {
            let files = Arc::new(files);
            watch_network(Arc::downgrade(&files));
            files
        }
        Err(error) => {
            // Never show fixture data in place of the user's files: fixtures
            // are only for `--fixture`. The service manager restarts Files.
            eprintln!("hensou-files: the backend failed to start: {error:?}");
            std::process::exit(1);
        }
    }
}

/// Network changes retry SSH connections at once (files.md). NetworkManager
/// announces them on the system bus; without it, core's own backoff still
/// reconnects.
fn watch_network(files: std::sync::Weak<hensou_files_core::Files>) {
    std::thread::Builder::new()
        .name("files-network".into())
        .spawn(move || {
            let Ok(connection) = zbus::blocking::Connection::system() else {
                return;
            };
            let Ok(proxy) = zbus::blocking::Proxy::new(
                &connection,
                "org.freedesktop.NetworkManager",
                "/org/freedesktop/NetworkManager",
                "org.freedesktop.NetworkManager",
            ) else {
                return;
            };
            let Ok(signals) = proxy.receive_signal("StateChanged") else {
                return;
            };
            for _ in signals {
                match files.upgrade() {
                    Some(files) => files.network_changed(),
                    None => return,
                }
            }
        })
        .ok();
}

/// The Phase 5 provider runs inside this process and listens on
/// `hensou_desktop_protocol::socket_path()`. Its requests use ids from
/// `1 << 48` up (bridge::REQUEST_LIMIT); the app stays below. A failure is
/// logged; Files windows keep working without desktop icons.
fn start_desktop_provider(service: Arc<dyn FilesService>, platform: &Platform) {
    static PROVIDER: OnceLock<hensou_desktop::ProviderHandle> = OnceLock::new();
    if fixture_selected() {
        return;
    }
    let started = (|| -> std::io::Result<hensou_desktop::ProviderHandle> {
        let path = hensou_desktop_protocol::socket_path()
            .ok_or_else(|| std::io::Error::other("XDG_RUNTIME_DIR is not set"))?;
        let icons = Arc::new(hensou_file_icons::ThemeIcons::from_env());
        let provider = hensou_desktop::DesktopProvider::new(
            service,
            platform.trash.clone(),
            platform.volumes.clone(),
            icons,
            hensou_desktop::Config::from_env()?,
        )?;
        provider.serve(path)
    })();
    match started {
        Ok(handle) => {
            // Dropping the handle stops the provider: keep it for the process life.
            let _ = PROVIDER.set(handle);
        }
        Err(error) => eprintln!("hensou-files: desktop icons are unavailable: {error}"),
    }
}

struct NoTrash;

impl TrashStore for NoTrash {
    fn delete_kind(&self, _: &Path) -> DeleteKind {
        DeleteKind::Permanent {
            reason: "The Trash is unavailable.".into(),
        }
    }
    fn trash(&self, _: &Path) -> Result<PathBuf, FilesError> {
        Err(FilesError::Unsupported {
            what: "Trash".into(),
        })
    }
    fn items(&self) -> Result<Vec<TrashItem>, FilesError> {
        Ok(Vec::new())
    }
    fn restore(&self, _: &Path) -> Result<PathBuf, FilesError> {
        Err(FilesError::Unsupported {
            what: "Trash".into(),
        })
    }
    fn empty(&self) -> Result<u64, FilesError> {
        Ok(0)
    }
    fn watch(&self, _: Box<dyn Fn() + Send + Sync>) {}
}

struct NoVolumes;

impl VolumeMonitor for NoVolumes {
    fn volumes(&self) -> Vec<Volume> {
        Vec::new()
    }
    fn eject(&self, _: &str) -> Result<(), FilesError> {
        Err(FilesError::Unsupported {
            what: "Eject".into(),
        })
    }
    fn watch(&self, _: Box<dyn Fn(Vec<Volume>) + Send + Sync>) {}
}
