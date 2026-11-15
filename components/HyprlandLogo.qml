import "../config/"
import QtQuick
import QtQuick.Effects

// The Hyprland logo in one colour (the file is white; it is tinted here).
Item {
    id: root

    property color color: Appearance.fgColor
    property int size: 24

    implicitWidth: size
    implicitHeight: size

    Image {
        id: logo

        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/hyprland.svg")
        sourceSize.width: root.size * 3
        sourceSize.height: root.size * 3
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: logo
        source: logo
        colorization: 1
        colorizationColor: root.color
    }
}
