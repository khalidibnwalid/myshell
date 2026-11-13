import "../config/"
import QtQuick
import QtQuick.Layouts

// Sub-page header: back button, title + subtitle, optional actions on the right.
RowLayout {
    id: root

    property string title
    property string subtitle
    default property alias actions: actionsRow.data

    signal back()

    spacing: 12

    Rectangle {
        implicitWidth: 36
        implicitHeight: 36
        radius: 18
        color: backArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor
        scale: backArea.pressed ? 0.92 : 1

        MaterialSymbol {
            anchors.centerIn: parent
            icon: "arrow_back"
            font.pixelSize: 18
            color: Appearance.fgColor
        }

        MouseArea {
            id: backArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animFast
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animFast
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: 17
            font.weight: Font.Bold
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.subtitle
            elide: Text.ElideRight
            font.pixelSize: 12
            color: Appearance.mutedColor
        }
    }

    RowLayout {
        id: actionsRow

        spacing: 4
    }
}
