import QtQuick

// One provider per visual window. Bind devicePixelRatio to actual native window
// metrics; Screen.devicePixelRatio rounds fractional scale on some Qt platforms.
Item {
    property var hostWindow: null
    property real devicePixelRatio: hostWindow && hostWindow.devicePixelRatio > 0
        ? hostWindow.devicePixelRatio : 1.5
    property var iconResolver: null
    readonly property real hensouDevicePixelRatio: devicePixelRatio
    readonly property var hensouIconResolver: iconResolver
}
