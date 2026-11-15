import "../../../config"
import QtQuick

// A small mark in a miniature (an icon, a workspace, a line of the clock), for the style pickers.
Rectangle {
    property real w: 3
    property real h: 3
    property color tone: Appearance.fgColor

    width: w
    height: h
    radius: Math.min(w, h) / 2
    color: tone
    opacity: 0.75
}
