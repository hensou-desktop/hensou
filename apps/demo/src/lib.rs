use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QString, QUrl};

pub fn run() -> i32 {
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    let Some(mut engine) = engine.as_mut() else {
        eprintln!("Cannot create the Qt Quick engine");
        std::process::exit(1);
    };
    // The installed kit is independent of this executable. A single import URI
    // prevents a second Theme singleton through a directory-import alias.
    if let Some(path) = std::env::var_os("HENSOU_QML_IMPORT_PATH") {
        engine
            .as_mut()
            .add_import_path(&QString::from(path.to_string_lossy().as_ref()));
    }
    engine
        .as_mut()
        .load(&QUrl::from("qrc:/qt/qml/Hensou/Demo/qml/Main.qml"));
    if !hensou_qt_host::engine_has_roots(&engine) {
        eprintln!(
            "Cannot load Hensou demo; set HENSOU_QML_IMPORT_PATH to the parent of Hensou/qmldir"
        );
        std::process::exit(1);
    }
    if let Some(mut app) = app.as_mut() {
        return app.exec();
    }
    1
}

/// The test binary consumes this library, including its compiled QML module.
pub fn link_resources() {
    let _ = hensou_qt_host::engine_has_roots;
}
