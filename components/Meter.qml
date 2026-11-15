import "../config/"
import QtQuick

// Thin horizontal level bar, value 0–1
Rectangle {
    id: root

    property real value: 0
    property color fillColor: Appearance.accentColor

    implicitWidth: 160
    implicitHeight: 8
    radius: height / 2
    color: Appearance.surfaceHighColor

    Rectangle {
        height: parent.height
        width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
        radius: height / 2
        color: root.fillColor

        Behavior on width {
            NumberAnimation {
                duration: Appearance.animSlow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.easeOut
            }
        }
    }
}
