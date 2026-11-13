import QtQuick
import Quickshell.Io
pragma Singleton

JsonObject {
    property color bgColor: Config.appearance.bgColor
    property color fgColor: Config.appearance.fgColor
    property color accentColor: Config.appearance.accentColor
    property color accentColorLight: Config.appearance.accentColorLight
    property color highlightColor: Config.appearance.highlightColor
    property color borderColor: Config.appearance.borderColor
    // Derived surfaces so everything follows the user's color settings
    // Panels are slightly see-through; the compositor blurs what is behind them
    readonly property real panelOpacity: Math.max(0.35, Math.min(1, Config.appearance.opacity))
    readonly property color panelColor: Qt.alpha(bgColor, panelOpacity)
    readonly property color hairlineColor: Qt.alpha(fgColor, 0.08)
    // Surfaces are overlays so they stay translucent on top of a panel
    readonly property color surfaceColor: Qt.alpha(fgColor, 0.07)
    readonly property color surfaceHighColor: Qt.alpha(fgColor, 0.13)
    readonly property color outlineColor: Qt.alpha(fgColor, 0.22)
    readonly property color mutedColor: Qt.alpha(fgColor, 0.62)
    readonly property color onAccentColor: bgColor
    readonly property string fontFamily: Config.appearance.fontFamily
    // Motion: one decelerating curve for things entering, one standard curve for the rest
    readonly property int animFast: 130
    readonly property int animNormal: 220
    readonly property int animSlow: 340
    readonly property var easeOut: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeStandard: [0.2, 0, 0, 1, 1, 1]
}
