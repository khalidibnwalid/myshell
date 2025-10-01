import "../../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    required property var timeParts

    spacing: -16
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignHCenter

    Text {
        Layout.alignment: Qt.AlignHCenter
        color: Appearance.fgColor
        font.pixelSize: 28
        font.family: "Roboto Mono"
        font.weight: Font.Bold
        text: parent.timeParts[0]
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        color: Appearance.fgColor
        font.pixelSize: 28
        font.weight: Font.Bold
        text: parent.timeParts[1]
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        color: Appearance.fgColor
        font.pixelSize: 24
        font.weight: Font.Bold
        text: parent.timeParts[2]
    }
}
