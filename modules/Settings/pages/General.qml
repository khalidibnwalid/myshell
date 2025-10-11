import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"

Item {
    ColumnLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24
        spacing: 20

        Text {
            text: "General Settings"
            font.pixelSize: 32
            font.weight: Font.Bold
            color: Appearance.fgColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                text: "Language"
                font.pixelSize: 18
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignVCenter
            }

            Button {
                text: "English"
                endIcon: "arrow_drop_down"
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
