import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    implicitHeight: layout.implicitHeight + 12
    Component.onCompleted: {
        if (Bluetooth.enabled && !Bluetooth.isScanning) {
            Bluetooth.toggleScan();
            scanTimer.start();
        }
    }

    Timer {
        id: scanTimer

        interval: 10000 // Scan for 10 seconds
        onTriggered: {
            if (Bluetooth.isScanning) {
                Bluetooth.toggleScan();
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 10

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
                    text: "Bluetooth"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: Appearance.fgColor
                }

                Text {
                    text: Bluetooth.enabled ? (Bluetooth.connectedDevices.length ? Bluetooth.connectedDevices[0].name : "Discovery On") : "Off"
                    font.pixelSize: 12
                    color: Appearance.fgColor
                    opacity: 0.5
                }

            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 4

                IconButton {
                    icon: "sensors"
                    toggled: Bluetooth.isScanning
                    onClicked: Bluetooth.toggleScan()
                }

                IconButton {
                    icon: "bluetooth"
                    toggled: Bluetooth.enabled
                    onClicked: Bluetooth.toggle()
                    accentColor: Appearance.accentColor
                }

            }

        }

        ListView {
            model: Bluetooth.devices
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Bluetooth.devices.length * 64, 256)
            spacing: 3
            currentIndex: -1
            clip: true

            delegate: RowLayout {
                width: parent.width
                spacing: 3

                ToggleButton {
                    text: modelData.name
                    Layout.fillWidth: true
                    toggled: modelData.connected
                    onClicked: modelData.connected = !modelData.connected
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    icon: {
                        const icon = modelData.icon.toLowerCase();
                        // ref: /usr/share/icons/Adwaita/scalable/devices
                        if (icon.includes("headphone") || icon.includes("headset"))
                            return "headphones";

                        if (icon.includes("microphone"))
                            return "mic";

                        if (icon.includes("keyboard"))
                            return "keyboard";

                        if (icon.includes("mouse"))
                            return "mouse";

                        if (icon.includes("printer"))
                            return "print";

                        return "general_device";
                    }
                }

                //battery status
                ToggleButton {
                    visible: modelData.batteryAvailable
                    text: modelData.battery * 100 + "%"
                    icon: "battery_android_0"
                    iconFill: modelData.battery
                    Layout.preferredWidth: 110
                    toggled: false
                    enabled: false
                }

            }

        }

    }

}
