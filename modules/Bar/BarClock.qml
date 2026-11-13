import "../../components"
import "../../config"
import "../../services"
import QtQuick
import QtQuick.Layouts

// Clock pill: hours, accent minutes, then weekday and day of month
Rectangle {
    implicitWidth: 40
    implicitHeight: column.implicitHeight + 32
    radius: 20
    color: Appearance.surfaceColor

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        spacing: 0

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: 17
            font.weight: Font.Bold
            // 12-hour clock without am/pm
            text: Time.format("hh ap").replace(/ ?[ap]m/i, "")
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            color: Appearance.accentColor
            font.pixelSize: 17
            font.weight: Font.Bold
            text: Time.format("mm")
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            implicitWidth: 14
            implicitHeight: 1
            color: Appearance.outlineColor
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            color: Appearance.mutedColor
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 1
            text: Time.format("ddd").toUpperCase()
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            font.pixelSize: 14
            font.weight: Font.DemiBold
            text: Time.format("d")
        }
    }
}
