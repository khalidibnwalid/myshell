import "../../components/"
import "../../config/"
import "../../services" as Services
import QtQuick

// Shown in the bar only while a screen recording runs: a solid red capsule with a beating dot and the
// time. Pointing at it turns the dot into a stop square; a click ends the recording and saves the file.
Rectangle {
    id: root

    readonly property bool horizontal: Config.barHorizontal
    readonly property bool active: Services.ScreenTools.recording
    readonly property color ink: "#3a0a0a"

    visible: active
    implicitWidth: horizontal ? row.implicitWidth + 22 : 36
    implicitHeight: horizontal ? 32 : col.implicitHeight + 18
    radius: Math.min(implicitWidth, implicitHeight) / 2 > 18 ? 18 : Math.min(implicitWidth, implicitHeight) / 2
    color: area.containsMouse ? "#ff8585" : "#ff5f5f"
    scale: area.pressed ? 0.94 : 1
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            Services.ScreenTools.stopRecording();
            event.accepted = true;
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Stop recording, " + Services.ScreenTools.elapsedText

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.easeFade
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.easeStandard
        }
    }

    // the beating dot, with a ring that spreads from it; under the pointer it becomes a stop square
    component Marker: Item {
        implicitWidth: 16
        implicitHeight: 16

        Rectangle {
            id: ring

            anchors.centerIn: parent
            width: 16
            height: 16
            radius: 8
            color: "transparent"
            border.width: 1.5
            border.color: root.ink
            opacity: area.containsMouse ? 0 : 0.5

            ParallelAnimation {
                running: root.active
                loops: Animation.Infinite

                NumberAnimation {
                    target: ring
                    property: "scale"
                    from: 0.5
                    to: 1.15
                    duration: 1300
                    easing.type: Easing.OutCubic
                }

                SequentialAnimation {
                    NumberAnimation {
                        target: ring
                        property: "opacity"
                        from: 0.6
                        to: 0
                        duration: 1300
                    }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: area.containsMouse ? 9 : 8
            height: width
            radius: area.containsMouse ? 2.5 : width / 2
            color: root.ink

            Behavior on radius {
                NumberAnimation {
                    duration: Appearance.animFast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeStandard
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.animFast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeStandard
                }
            }
        }
    }

    component Time: StyledText {
        text: Services.ScreenTools.elapsedText
        font.pixelSize: 11
        font.weight: Font.Bold
        color: root.ink
        font.features: {
            "tnum": 1
        }
    }

    // a top or bottom bar: dot and time side by side
    Row {
        id: row

        visible: root.horizontal
        anchors.centerIn: parent
        spacing: 6

        Marker {
            anchors.verticalCenter: parent.verticalCenter
        }

        Time {
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // a side bar: dot over the time
    Column {
        id: col

        visible: !root.horizontal
        anchors.centerIn: parent
        spacing: 2

        Marker {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Time {
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    FocusRing {
        radius: root.radius
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.ScreenTools.stopRecording()
    }
}
