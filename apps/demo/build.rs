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
            ]),
    )
    .qrc("qml/resources.qrc")
    .qt_module("Quick")
    .qt_module("QuickTest")
    .file("src/test_main.rs")
    .include_dir("src")
    .cpp_file("src/test_runner.cpp")
    .cpp_file("src/test_runner.h")
    .build();
}
