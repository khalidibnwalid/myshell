import "../../config/"
import "../../services"
import "../../components/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView
    property var wifiPageComponent
    property var bluetoothPageComponent
    property var batteryPageComponent

    ColumnLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 3

        GridLayout {
            id: contentGrid
            columns: 2
            rowSpacing: 14
            columnSpacing: 14
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true

            Button {
                text: "Wi-Fi"
                icon: "wifi"
                endIcon: "arrow_forward_ios"
                onClicked: stackView.push(wifiPageComponent, {
                    "stackView": stackView
                })
            }

            Button {
                text: "Bluetooth"
                icon: "bluetooth"
                endIcon: "arrow_forward_ios"
                onClicked: stackView.push(bluetoothPageComponent, {
                    "stackView": stackView
                })
            }

            Button {
                text: "Battery"
                icon: "energy_savings_leaf"
                endIcon: "arrow_forward_ios"
                onClicked: stackView.push(batteryPageComponent, {
                    "stackView": stackView
                })
            }

            Button {
                text: "settings"
                icon: "settings"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 30
            anchors.margins: 20

            MaterialSymbol {
                icon: "volume_up"
                color: Appearance.fgColor
                font.pixelSize: 32
            }
            Slider {
                value: 0
                width: 330
                //value: Pipewire.defaultAudioSink?.audio.volume ?? 0
            }
        }
    }
}
