import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
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

            Text {
                text: "Battery - " + Math.round(Battery.percentage * 100) + "%"
                font.pixelSize: 24
                font.weight: Font.DemiBold
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignHCenter
            }

            MaterialSymbol {
                icon: Battery.iconName
                font.pixelSize: 36
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignHCenter
                fill: Battery.percentage
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            Layout.margins: 10

            Text {
                text: "Power Profiles"
                font.pixelSize: 20
                font.weight: Font.Bold
                color: Appearance.fgColor
            }

            Repeater {
                model: Battery.powerProfilesList
                delegate: ToggleButton {
                    text: modelData.name
                    icon: modelData.icon
                    Layout.fillWidth: true

                    toggled: Battery.activeProfile === modelData.key
                    onClicked: Battery.setProfile(modelData.key)
                }
            }
        }
    }
}
