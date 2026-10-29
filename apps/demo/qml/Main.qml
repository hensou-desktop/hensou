import QtQuick
import Hensou.Host

Window {
    width: 640
    height: 480
    visible: true
    title: "Hensou host bootstrap"
    WindowMetrics { id: metrics }
    Component.onCompleted: console.log("HOST_READY", HostTheme.name, HostTheme.mode, metrics.devicePixelRatio)
}
