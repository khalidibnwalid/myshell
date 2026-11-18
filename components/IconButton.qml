import "../config/"
import QtQuick

Item {
    id: root

    property string icon: ""
    property color color: Appearance.fgColor
    property int iconSize: 22
    property real iconFill: 0
    property int size: 36
    property bool toggled: false
    property color accentColor: Appearance.accentColor
    readonly property bool hovered: mouseArea.containsMouse

    signal clicked()

    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }
    // Space is the player's play key in some windows: a focused button keeps it
    Keys.onShortcutOverride: event => {
        if (event.key === Qt.Key_Space)
            event.accepted = true;
    }
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
        fill: root.iconFill
        font.pixelSize: root.iconSize
        color: root.toggled ? root.accentColor : root.color
        opacity: mouseArea.containsMouse || root.toggled ? 1 : 0.5

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

    }

    FocusRing {
        radius: root.size / 2
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

}
