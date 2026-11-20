pragma Singleton
import QtQuick

// install.sh rewrites the first five values from your quickshell config; these are the fallbacks
QtObject {
    readonly property color bgColor: "#0f1417"
    readonly property color fgColor: "#dfe3e7"
    readonly property color accentColor: "#92cef5"
    readonly property color accentColorLight: "#abdeff"
    readonly property string fontFamily: "Adwaita Sans"

    readonly property bool isLight: bgColor.hslLightness > 0.55
    readonly property real accentBrightness: 0.2126 * accentColor.r + 0.7152 * accentColor.g + 0.0722 * accentColor.b
    readonly property color accentContrastColor: {
        const darker = isLight ? fgColor : bgColor;
        const lighter = isLight ? bgColor : fgColor;
        return accentBrightness > 0.5 ? darker : lighter;
    }
    readonly property color mutedColor: Qt.alpha(fgColor, 0.62)
    readonly property int animFast: 130
    readonly property int animSlow: 340
    readonly property var easeOut: [0.05, 0.7, 0.1, 1, 1, 1]
}
