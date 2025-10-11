import "../../config/"
import "../../services/"
import "../../components/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView
    property var networkPageComponent
    property var bluetoothPageComponent
    property var batteryPageComponent

    implicitHeight: layout.implicitHeight + 24

    Audio {
        id: audio
    }

    ColumnLayout {
        id: layout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 12
        // TODO: maybe make this customizable?
        GridLayout {
            id: contentGrid
            columns: 2
            rowSpacing: 14
            columnSpacing: 14
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true

            ToggleButton {
                toggled: Network.enabled
                text: Network.connected ? Network.active.ssid : Network.enabled ? "Available" : "Disabled"
                icon: Network.statusIcon
                endIcon: "arrow_forward_ios"
                onClicked: stackView.push(networkPageComponent, {
                    "stackView": stackView
                })
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            ToggleButton {
                toggled: Bluetooth.enabled
                text: Bluetooth.connectedDevices.length ? Bluetooth.connectedDevices[0].name : "Bluetooth"
                icon: Bluetooth.statusIcon
                endIcon: "arrow_forward_ios"
                onClicked: stackView.push(bluetoothPageComponent, {
                    "stackView": stackView
                })
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            // TODO: disable on isLaptopBattery = false, but I don't know what to swap it with
            Button {
                text: "Battery " + Math.round(Battery.percentage * 100) + "%"
                icon: Battery.activeProfileIcon
                endIcon: "arrow_forward_ios"
                onClicked: stackView.push(batteryPageComponent, {
                    "stackView": stackView
                })
            }

            // TODO
            ToggleButton {
                toggled: false
                text: "settings"
                icon: "settings"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            anchors.margins: 20

            MaterialSymbol {
                icon: audio.volume === 0 ? "volume_mute" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
                color: Appearance.fgColor
                font.pixelSize: 32
            }

            Slider {
                value: audio.volume
                width: 330
                onDragged: audio.setVolume(value)
            }
        }
    }
}
