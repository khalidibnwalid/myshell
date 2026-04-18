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
            spacing: 8

            IconButton {
                icon: "arrow_back"
                onClicked: stackView.pop()
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Battery"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: Appearance.fgColor
                }

                Text {
                    text: Math.round(Battery.percentage * 100) + "% - " + Battery.stateString
                    font.pixelSize: 12
                    color: Appearance.fgColor
                    opacity: 0.5
                }

            }

            Item {
                Layout.fillWidth: true
            }

            MaterialSymbol {
                icon: Battery.iconName
                font.pixelSize: 24
                color: Appearance.fgColor
                opacity: 0.8
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
