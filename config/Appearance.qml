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
}
