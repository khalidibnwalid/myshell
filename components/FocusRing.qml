import "../config/"
import QtQuick

// The outline of the control that has the keyboard focus. Put it inside the control: it fills it and shows
// while the control has the focus.
Rectangle {
    property real gap: 2
    property color ringColor: Appearance.accentColor

    anchors.fill: parent
    anchors.margins: -gap
    radius: parent && parent.radius !== undefined ? parent.radius + gap : 8
    color: "transparent"
    border.width: 2
    border.color: ringColor
    visible: parent && parent.activeFocus
    z: 10
}
