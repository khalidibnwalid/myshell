import QtQuick
import QtQuick.Layouts
import "../../../config"

Item {
    ColumnLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24
        spacing: 20

        Text {
            text: "About"
            font.pixelSize: 32
            font.weight: Font.Bold
            color: Appearance.fgColor
        }

        Text {
            text: "Version 1.0.0"
            font.pixelSize: 18
            color: Appearance.fgColor
        }
    }
}
