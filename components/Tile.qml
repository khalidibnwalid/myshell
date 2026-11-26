import "../config/"
import QtQuick
import QtQuick.Layouts

// Pill-shaped quick settings tile: accent filled when active, surface when not.
Rectangle {
    id: root

    property string text
    property string icon
    property real iconFill: 0
    property bool toggled: false
    readonly property color contentColor: toggled ? Appearance.accentContrastColor : Appearance.fgColor

    signal clicked()

    implicitHeight: 54
    radius: height / 2
    color: toggled ? (mouseArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor) : (mouseArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor)
    scale: mouseArea.pressed ? 0.97 : 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 16
        spacing: 12

        MaterialSymbol {
            icon: root.icon
            fill: root.iconFill
            font.pixelSize: 20
            color: root.contentColor
        }

        StyledText {
            Layout.fillWidth: true
            text: root.text
            elide: Text.ElideRight
            font.weight: Font.Medium
            color: root.contentColor
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animNormal
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
}
