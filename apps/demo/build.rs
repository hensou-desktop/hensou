use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("Hensou.Demo")
            .qml_files([
                "qml/Main.qml",
                "qml/DemoWindow.qml",
                "qml/DemoButton.qml",
                "qml/DemoField.qml",
                "qml/DemoCheckBox.qml",
                "qml/DemoList.qml",
                "qml/DemoLabel.qml",
                "qml/DemoMenu.qml",
                "qml/DemoDialog.qml",
            ])
            .qml_file("qml/LayoutPlan.js"),
    )
    .qt_module("Quick")
        .qt_module("QuickTest")
        .file("src/test_main.rs")
        .include_dir("src")
        .cpp_file("src/test_runner.cpp")
    .build();
}
