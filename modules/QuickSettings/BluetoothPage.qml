import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    ColumnLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Button {
                icon: "arrow_back"
                onClicked: stackView.pop()
                Layout.preferredWidth: 60
            }

            MaterialSymbol {
                icon: "bluetooth"
                font.pixelSize: 24
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Bluetooth"
                font.pixelSize: 24
                font.weight: Font.DemiBold
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
