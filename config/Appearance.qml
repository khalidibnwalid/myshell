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
    readonly property real panelOpacity: Math.max(0, Math.min(1, Config.appearance.opacity))
    // a pale panel that is half see-through turns into a dull grey over dark windows, so
    // light themes get a stronger tint for the same opacity setting (0% and 100% are unchanged)
    readonly property bool isLight: bgColor.hslLightness > 0.55
    readonly property real panelAlpha: isLight ? 1 - Math.pow(1 - panelOpacity, 2) : panelOpacity
    readonly property color panelColor: Qt.alpha(bgColor, panelAlpha)
    // 0 from 45% panel opacity up; fades in to 1 at 20% and below. The bar's icon groups
    // then sit on floating islands instead of the bar background.
    readonly property real islandAmount: Math.max(0, Math.min(1, (0.45 - panelOpacity) / 0.25))
    readonly property color hairlineColor: Qt.alpha(fgColor, 0.08)
    // Surfaces are overlays so they stay translucent on top of a panel
    readonly property color surfaceColor: Qt.alpha(fgColor, 0.07)
    readonly property color surfaceHighColor: Qt.alpha(fgColor, 0.13)
    readonly property color outlineColor: Qt.alpha(fgColor, 0.22)
    readonly property color mutedColor: Qt.alpha(fgColor, 0.62)
    // text and icons on the accent colour: the theme's dark or light colour, whichever reads better on it
    // (the accent's brightness decides, so a pale accent gets dark text and a deep one light text)
    readonly property real accentBrightness: 0.2126 * accentColor.r + 0.7152 * accentColor.g + 0.0722 * accentColor.b
    readonly property color accentContrastColor: {
        const darker = isLight ? fgColor : bgColor;
        const lighter = isLight ? bgColor : fgColor;
        return accentBrightness > 0.5 ? Qt.rgba(darker.r, darker.g, darker.b, 1) : Qt.rgba(lighter.r, lighter.g, lighter.b, 1);
    }
    readonly property string fontFamily: Config.appearance.fontFamily
    // Motion: one decelerating curve for things entering, one standard curve for the rest
    readonly property int animFast: 130
    readonly property int animNormal: 220
    readonly property int animSlow: 340
    readonly property var easeOut: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeStandard: [0.2, 0, 0, 1, 1, 1]
}
