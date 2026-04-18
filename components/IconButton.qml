import "../config/"
import QtQuick

Item {
    id: root

    property string icon: ""
    property color color: Appearance.fgColor
    property int iconSize: 22
    property int size: 36
    property bool toggled: false
    property color accentColor: Appearance.accentColor

    signal clicked()

    implicitWidth: size
    implicitHeight: size

    // The "ghost" background
    Rectangle {
        id: bg

        anchors.fill: parent
        radius: size / 2
        color: root.toggled ? root.accentColor : root.color
        opacity: root.toggled ? (mouseArea.containsMouse ? 0.2 : 0.1) : (mouseArea.containsMouse ? 0.1 : 0)

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

    }

    MaterialSymbol {
        anchors.centerIn: parent
        icon: root.icon
        font.pixelSize: root.iconSize
        color: root.toggled ? root.accentColor : root.color
        opacity: mouseArea.containsMouse || root.toggled ? 1 : 0.5

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

}
