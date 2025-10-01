pragma Singleton

import QtQuick
import Quickshell.Io

JsonObject {
    property color bgColor: Config.appearance.bgColor
    property color fgColor: Config.appearance.fgColor
    property color accentColor: Config.appearance.accentColor
    property color highlightColor: Config.appearance.highlightColor
    property color borderColor: Config.appearance.bordercolor
}
