import QtQuick
import QtQuick.Layouts
import "../config/"

Rectangle {
    required property real value
    // required property real value
    // required property real value
    // required property real value
    //   required property real value

    implicitHeight: 10
    radius: 10
    color: Appearance.highlightColor // slider background

    // slider fill
    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }

        implicitWidth: parent.width * value
        radius: parent.radius
        color: Appearance.accentColor

        Behavior on implicitWidth {
            NumberAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }
        }
    }

    Rectangle {
        width: 43
        height: 28
        radius: 10
        color: Appearance.accentColor
        opacity: 0.3

        y: parent.height / 2 - height / 2
        x: (parent.width * value) - width / 2
        Behavior on x {
            NumberAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: parent.radius
            border.color: Appearance.accentColor
            border.width: 2
        }
    }

    Rectangle {
        width: 35
        height: 20
        radius: 7
        color: Appearance.accentColor

        y: parent.height / 2 - height / 2
        x: (parent.width * value) - width / 2
        Behavior on x {
            NumberAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }
        }
    }
}
