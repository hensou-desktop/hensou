//! Files: the resident Hensou file manager. One process owns every Files
//! window, the transfers and (after Integrate) the desktop provider.

pub mod bridge;
pub mod cli;
pub mod hyprland;
pub mod instance;
pub mod scenario;
pub mod seam;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QString, QUrl};

mod native;

/// The machine's name as the Platinum Computer window shows it ("Myoko").
/// `HENSOU_FILES_HOSTNAME` overrides it for fixtures and captures.
pub fn hostname() -> String {
    let raw = std::env::var("HENSOU_FILES_HOSTNAME")
        .ok()
        .filter(|v| !v.trim().is_empty())
        .or_else(|| std::fs::read_to_string("/proc/sys/kernel/hostname").ok())
        .unwrap_or_else(|| "Computer".into());
    display_hostname(&raw)
}

/// `myoko.local` reads as "Myoko".
pub fn display_hostname(raw: &str) -> String {
    let short = raw.trim().split('.').next().unwrap_or_default();
    let mut letters = short.chars();
    match letters.next() {
        Some(first) => first.to_uppercase().chain(letters).collect(),
        None => "Computer".into(),
    }
}

/// Runs the resident process. The caller has already claimed the socket.
pub fn run(launch: cli::Launch, resident: instance::Resident) -> i32 {
    let mut app = QGuiApplication::new();
    hensou_qt_host::configure_graphics();
    native::ffi::keep_resident();
    let fonts = std::env::var("HENSOU_FONT_DIRECTORY").unwrap_or_default();
    if !hensou_qt_host::register_fonts(&QString::from(fonts.as_str())) {
        eprintln!("Set HENSOU_FONT_DIRECTORY to the packaged Hensou fonts");
        return 1;
    }
    seam::start(seam::wants_fixture(launch.fixture));
    for request in launch.requests {
        bridge::deliver(request);
    }
    resident.serve(bridge::deliver);
    let mut engine = QQmlApplicationEngine::new();
    let Some(mut engine) = engine.as_mut() else {
        eprintln!("Cannot create the Qt Quick engine");
        return 1;
    };
    // One Hensou import URI, so there is one Theme singleton.
    if let Some(path) = std::env::var_os("HENSOU_QML_IMPORT_PATH") {
        engine
            .as_mut()
            .add_import_path(&QString::from(path.to_string_lossy().as_ref()));
    }
    engine
        .as_mut()
        .load(&QUrl::from("qrc:/qt/qml/Hensou/Files/qml/Main.qml"));
    if !hensou_qt_host::engine_has_roots(&engine) {
        eprintln!("Cannot load Files; set HENSOU_QML_IMPORT_PATH to the parent of Hensou/qmldir");
        return 1;
    }
    match app.as_mut() {
        Some(app) => app.exec(),
        None => 1,
    }
}

/// The test binary links the same compiled QML module and native code.
pub fn link_resources() {
    let _ = hensou_qt_host::engine_has_roots;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hostnames_read_as_names() {
        assert_eq!(display_hostname("myoko\n"), "Myoko");
        assert_eq!(display_hostname("aka.lan"), "Aka");
        assert_eq!(display_hostname(""), "Computer");
    }
}
