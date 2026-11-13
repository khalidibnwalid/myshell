import "../config/"
import QtQuick

// On/off switch. `checked` is set by the owner; a click only emits toggled().
Item {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 52
    implicitHeight: 32
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? (area.containsMouse ? Appearance.accentColorLight : Appearance.accentColor) : (area.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor)
        border.width: root.checked ? 0 : 2
        border.color: Appearance.outlineColor

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animFast
            }
        }
    }

    Rectangle {
        readonly property real size: root.checked ? 24 : 16

        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - size - 4 : 8
        width: size + (area.pressed ? 4 : 0)
        height: size
        radius: height / 2
        color: root.checked ? Appearance.onAccentColor : Appearance.mutedColor

        Behavior on x {
            NumberAnimation {
                duration: Appearance.animNormal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.easeOut
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Appearance.animFast
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Appearance.animFast
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
