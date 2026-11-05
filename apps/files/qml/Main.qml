import QtQuick
import Hensou
import Hensou.Host

// The process's root. Exactly one kit Theme singleton in this engine; the
// host adapter watches the theme state files.
FilesApp {
    property Binding themeName: Binding { target: Theme; property: "name"; value: HostTheme.name }
    property Binding themeMode: Binding { target: Theme; property: "mode"; value: HostTheme.mode }
    property Binding themeExtra: Binding { target: Theme; property: "extraState"; value: HostTheme.extraState }
}
