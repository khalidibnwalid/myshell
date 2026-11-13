import "../config/"
import QtQuick
import QtQuick.Layouts

// Small text pill: surface by default, accent when toggled
Rectangle {
    id: root

    property string text
    property string icon
    property bool toggled: false
    readonly property color contentColor: toggled ? Appearance.onAccentColor : Appearance.fgColor

    signal clicked()

    implicitHeight: 36
    implicitWidth: row.implicitWidth + 32
    radius: height / 2
    color: toggled ? (mouseArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor) : (mouseArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor)
    scale: mouseArea.pressed ? 0.96 : 1

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 8

        MaterialSymbol {
            visible: root.icon !== ""
            icon: root.icon
            font.pixelSize: 18
            color: root.contentColor
        }

        StyledText {
            text: root.text
            font.pixelSize: 13
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
            duration: Appearance.animFast
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animFast
            easing.type: Easing.OutCubic
        }
    }
}
