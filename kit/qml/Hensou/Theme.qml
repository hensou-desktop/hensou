pragma Singleton
import QtQuick

// Appearance values only. Hosts own persistence, watchers, sounds and recovery.
QtObject {
    id: root
    property string name: "platinum"
    property string mode: "dark"
    property string extraState: "off"
    readonly property bool dark: mode !== "light"
    readonly property bool extraDark: extraState === "on"

    readonly property string fontFamily: "monospace"

    // Corner radii
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 6
    readonly property int radiusLarge: 8

    // Background surfaces. Dark keeps pure black so OLED pixels turn off.
    readonly property color bgBase: dark ? "#000000" : "#f5f5f5"
    readonly property color bgPanel: dark ? "#141414" : "#ffffff"
    readonly property color bgSelected: dark ? "#2a2a2a" : "#e4e4e4"
    readonly property color bgActive: dark ? "#303030" : "#dcdcdc"
    readonly property color bgInput: dark ? "#0d0d0d" : "#f8f8f8"
    readonly property color bgSeparator: dark ? "#3a3a3a" : "#c8c8c8"

    // The scrim behind the omni bar stays dark in both themes on purpose.
    // It sits over arbitrary windows, so a light scrim can land on a white
    // window and disappear, taking the modal signal with it. Dark also keeps
    // the white light-theme card separated from what is behind it.
    readonly property color bgVeil: "#b4000000"

    // Borders and accents
    readonly property color borderMuted: dark ? "#2e2e2e" : "#c0c0c0"
    readonly property color accent: dark ? "#6a9fb5" : "#3d7a94"
    readonly property color danger: dark ? "#d27d7d" : "#9f3333"
    readonly property color warning: dark ? "#d5a66f" : "#925b24"

    // Text hierarchy
    readonly property color textPrimary: dark ? "#e0e0e0" : "#1a1a1a"
    readonly property color textInput: dark ? "#e8e8e8" : "#101010"
    readonly property color textSecondary: dark ? "#c0c0c0" : "#303030"
    readonly property color textPage: dark ? "#c8c8c8" : "#383838"
    readonly property color textMuted: dark ? "#808080" : "#606060"
    readonly property color textHint: "#707070"
    readonly property color textDim: dark ? "#606060" : "#808080"
    readonly property color textDetail: dark ? "#6a6a6a" : "#787878"
    readonly property color textOff: dark ? "#404040" : "#b0b0b0"

}
