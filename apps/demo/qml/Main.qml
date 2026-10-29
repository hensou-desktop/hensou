import QtQuick
import Hensou
import Hensou.Host

DemoWindow {
    // Exactly one kit singleton in this engine. Watching stays in the host.
    Binding { target: Theme; property: "name"; value: HostTheme.name }
    Binding { target: Theme; property: "mode"; value: HostTheme.mode }
    Binding { target: Theme; property: "extraState"; value: HostTheme.extraState }
}
