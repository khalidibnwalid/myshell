import QtQuick
import QtQuick.Layouts
import "../config/"

Rectangle {
    id: root
    required property real value
    signal dragged(real value)

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
    }

    // hanlder
    Item {
        id: handler
        width: 43
        height: 28
        y: parent.height / 2 - height / 2
        x: (parent.width * value) - width / 2

        Rectangle {
            id: outerPart
            width: 43
            height: 28
            radius: 10
            color: Appearance.accentColor
            opacity: 0.3
            anchors.centerIn: parent

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: parent.radius
                border.color: Appearance.accentColor
                border.width: 2
            }
        }

        Rectangle {
            id: innerPart
            width: 35
            height: 20
            radius: 7
            color: Appearance.accentColor
            anchors.centerIn: parent
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onPositionChanged: {
            if (pressed)
                updateValue();
        }

        onClicked: updateValue()

        function updateValue() {
            var newValue = Math.max(0, Math.min(1, mouseX / width));
            root.value = newValue;
            root.dragged(newValue);
        }
    }

    states: [
        State {
            name: "pressed"
            when: mouseArea.pressed
            PropertyChanges {
                target: handler
                scale: 1.2
            }
            PropertyChanges {
                target: innerPart
                color: Appearance.accentColorLight
            }
            PropertyChanges {
                target: outerPart
                opacity: 0.15
            }
        }
    ]

    transitions: [
        Transition {
            ParallelAnimation {
                ColorAnimation {
                    duration: 100
                }
                NumberAnimation {
                    duration: 100
                }
            }
        }
    ]
}
