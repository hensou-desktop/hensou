//! The composition root's choice of `FilesService`, and the places where
//! Integrate plugs in the real backend and the desktop provider.
//!
//! ```text
//!   hensou-files ──► seam::start(fixture) ──► Arc<dyn FilesService>
//!                         │                        │
//!                         │                        ├─► bridge::install (QML)
//!                         │                        └─► desktop provider (Integrate)
//!                         └─ fixture: FixtureScenario(FakeFiles)
//!                            real:    hensou_files_core (Integrate)
//! ```

use crate::bridge;
use crate::cli::Request;
use crate::scenario::{FixtureScenario, ScenarioOptions};
use hensou_files_model::FilesService;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

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
    let service = choose(fixture);
    bridge::install(service.clone());
    start_desktop_provider(service.clone());
    service
}

fn choose(fixture: bool) -> Arc<dyn FilesService> {
    if fixture {
        FIXTURE.store(true, Ordering::Relaxed);
        return Arc::new(FixtureScenario::with_fixtures(ScenarioOptions::from_env()));
    }
    // INTEGRATE(files-core): replace this fallback with the real backend:
    //
    //     let config = hensou_files_core::Config {
    //         // Core asks Files to open a folder window (for example from a
    //         // desktop icon). It reaches the UI like a second launch.
    //         open_directory: Box::new(open_directory_hook),
    //         ..hensou_files_core::Config::default()
    //     };
    //     let files = Arc::new(hensou_files_core::Files::start(config));
    //     // Network changes retry SSH connections at once (files.md):
    //     // forward the session's network-change signal to
    //     // files.network_changed().
    //     return files;
    eprintln!(
        "hensou-files: the real backend is not linked in this build; using fixture data"
    );
    FIXTURE.store(true, Ordering::Relaxed);
    Arc::new(FixtureScenario::with_fixtures(ScenarioOptions::from_env()))
}

/// What core's `Config.open_directory` should call.
pub fn open_directory_hook(path: std::path::PathBuf) {
    bridge::deliver(Request::Open {
        location: hensou_files_model::Location::local(path),
    });
}

/// INTEGRATE(desktop): the Phase 5 provider runs inside this process and
/// listens on `hensou_desktop_protocol::socket_path()`. Its requests use ids
/// from `1 << 48` up (bridge::REQUEST_LIMIT); the app stays below. Integrate
/// fills in only this body:
///
/// ```text
/// let trash = Arc::new(hensou_trash::FreedesktopTrash::from_env()?);   // Result<_, FilesError>
/// let volumes = Arc::new(hensou_volumes::UdisksVolumes::connect()?);   // Result<_, FilesError>
/// let icons = Arc::new(hensou_file_icons::ThemeIcons::from_env());     // Self
/// let provider = hensou_desktop::DesktopProvider::new(
///     service, trash, volumes, icons, hensou_desktop::Config::default(),
/// )?;                                                                  // io::Result<Self>
/// let handle = provider.serve(hensou_desktop_protocol::socket_path())?; // io::Result<ProviderHandle>
/// // Dropping the handle stops the provider: keep it for the process life.
/// let _ = PROVIDER.set(handle);
/// ```
///
/// with `static PROVIDER: OnceLock<hensou_desktop::ProviderHandle>`. A
/// failure is logged; Files windows keep working without desktop icons.
fn start_desktop_provider(service: Arc<dyn FilesService>) {
    let _ = service;
}
