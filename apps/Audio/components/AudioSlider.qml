import "../../../config"
import ".."
import QtQuick

// A thin slider for the position and the volume. Dragging only previews; committed() fires on release.
Item {
    id: root

    property real value: 0
    property real dragValue: 0
    readonly property bool dragging: area.pressed
    readonly property real shown: dragging ? dragValue : value
    readonly property bool hovered: area.containsMouse

    signal moved(real value)
    signal committed(real value)

    implicitHeight: 18
    implicitWidth: 120

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.hovered || root.dragging ? 6 : 4
        radius: height / 2
        color: Appearance.surfaceHighColor

        Behavior on height {
            NumberAnimation {
                duration: Appearance.animFast
            }
        }

        Rectangle {
            width: Math.max(parent.height, parent.width * Math.min(1, Math.max(0, root.shown)))
            height: parent.height
            radius: height / 2
            color: root.hovered || root.dragging ? Appearance.accentColorLight : Appearance.accentColor
        }
    }

    Rectangle {
        x: Math.min(root.width, Math.max(0, root.width * root.shown)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 12
        radius: 6
        color: Appearance.fgColor
        visible: root.hovered || root.dragging
        scale: root.dragging ? 1.2 : 1
    }

    MouseArea {
        id: area

        function fraction(x) {
            return Math.min(1, Math.max(0, x / width));
        }

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            root.dragValue = fraction(mouse.x);
            root.moved(root.dragValue);
        }
        onPositionChanged: mouse => {
            if (pressed) {
                root.dragValue = fraction(mouse.x);
                root.moved(root.dragValue);
            }
        }
        onReleased: root.committed(root.dragValue)
        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.committed(Math.min(1, Math.max(0, root.value + step)));
        }
    }
}
