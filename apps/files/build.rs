use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(QmlModule::new("Hensou.Files").qml_files([
        "qml/Main.qml",
        "qml/FilesApp.qml",
        "qml/FilesStore.qml",
        "qml/FolderWindow.qml",
        "qml/PlatinumFolderFrame.qml",
        "qml/PlatinumTitleBar.qml",
        "qml/MemphisExplorerFrame.qml",
        "qml/FolderContent.qml",
        "qml/FolderTree.qml",
        "qml/MenuRow.qml",
        "qml/FilesMenu.qml",
        "qml/FilesText.qml",
        "qml/FilesButton.qml",
        "qml/FilesCheckBox.qml",
        "qml/FilesField.qml",
        "qml/FilesProgress.qml",
        "qml/EntryIcon.qml",
        "qml/AlertWindow.qml",
        "qml/InfoWindow.qml",
        "qml/TransfersWindow.qml",
        "qml/WindowEdges.qml",
    ]))
    .qrc("qml/resources.qrc")
    .qt_module("Quick")
    .qt_module("QuickTest")
    .qt_module("DBus")
    .files(["src/bridge.rs", "src/native.rs", "src/test_main.rs"])
    .include_dir("src")
    .cpp_files([
        "src/native.h",
        "src/native.cpp",
        "src/tray.h",
        "src/tray.cpp",
        "src/test_runner.h",
        "src/test_runner.cpp",
    ])
    .build();
}
