use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(QmlModule::new("Hensou.Host"))
        .qt_module("Quick")
        .file("src/theme.rs")
        .include_dir("src")
        .cpp_files([
            "src/window_metrics.h",
            "src/host.cpp",
            "src/modal_input_guard.h",
            "src/modal_input_guard.cpp",
        ])
        .build()
        .export();
}
