import "../config/"
import QtQuick

Button {
    id: root

    property bool toggled: false

    // Obsidian/High-Contrast style:
    // When ON: Solid Accent Color
    // When OFF: Pitch Black Background (#000000) with Blue Border
    fillColor: root.toggled ? Appearance.accentColor : Appearance.highlightColor
    borderColor: root.toggled ? Appearance.accentColor : Appearance.borderColor
    textColor: root.toggled ? Appearance.bgColor : Appearance.fgColor
    highlightColor: root.toggled ? Appearance.accentColorLight : Qt.alpha(Appearance.accentColor, 0.2)
    highlightTextColor: root.toggled ? Appearance.bgColor : Appearance.fgColor
    // Always solid backgrounds in this style
    backgroundOpacity: 1
}
