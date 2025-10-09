import "../config/"
import QtQuick

Button {
    id: root

    property bool toggled: false

    fillColor: root.toggled ? Appearance.accentColor : Appearance.highlightColor
    textColor: root.toggled ? Appearance.bgColor : Appearance.fgColor
    endIcon: ""
}
