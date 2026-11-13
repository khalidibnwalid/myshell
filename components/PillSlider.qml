import "../config/"
import QtQuick

// Horizontal pill slider: accent fill with the icon sitting at the fill's end.
Item {
    id: root

    property real value: 0
    property string icon: "light_mode"
    property int iconRightMargin: 14
    readonly property bool dragging: mouseArea.pressed
    readonly property bool hovered: mouseArea.containsMouse
    property real dragValue: 0
    readonly property real displayValue: dragging ? dragValue : value

    signal dragged(real value)

    Behavior on iconRightMargin {
        NumberAnimation { duration: Appearance.animFast }
    }

    implicitHeight: 48
    implicitWidth: 380

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Appearance.surfaceColor
        clip: true

        Rectangle {
            id: fill

            height: parent.height
            width: Math.max(height, parent.width * Math.min(Math.max(root.displayValue, 0), 1))
            radius: height / 2
            color: mouseArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animNormal
                }
            }

            Behavior on width {
                enabled: !root.dragging

                NumberAnimation {
                    duration: Appearance.animNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeOut
                }
            }

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: root.iconRightMargin
                icon: root.icon
                font.pixelSize: 20
                color: Appearance.onAccentColor
            }
        }
    }

    MouseArea {
        id: mouseArea

        function updateValue() {
            const v = Math.max(0, Math.min(1, mouseX / width));
            root.dragValue = v;
            root.dragged(v);
        }

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onPressed: {
            root.dragValue = root.value;
            updateValue();
        }
        onPositionChanged: {
            if (pressed)
                updateValue();
        }
        onWheel: wheel => root.dragged(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
