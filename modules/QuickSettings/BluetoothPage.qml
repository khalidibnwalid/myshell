import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    id: page

    property var stackView

    implicitHeight: layout.implicitHeight + 32

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: Bluetooth.closeContextMenu()
    }

    Component.onCompleted: {
        Bluetooth.startTracking();
        if (Bluetooth.enabled && !Bluetooth.isScanning) {
            Bluetooth.toggleScan();
            scanTimer.start();
        }
    }
    Component.onDestruction: {
        Bluetooth.closeContextMenu();
        Bluetooth.stopTracking();
        if (scanTimer.running && Bluetooth.isScanning)
            Bluetooth.toggleScan();
    }

    Timer {
        id: scanTimer

        interval: 20000 // scan for 20 seconds
        onTriggered: {
            if (Bluetooth.isScanning)
                Bluetooth.toggleScan();
        }
    }

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 14

        PageHeader {
            Layout.fillWidth: true
            title: "Bluetooth"
            subtitle: !Bluetooth.enabled ? "Off" : (Bluetooth.connectedDevices.length ? Bluetooth.connectedDevices.map(d => d.name).join(", ") : (Bluetooth.isScanning ? "Scanning…" : "On"))
            onBack: stackView.pop()

            // visible to other devices
            IconButton {
                icon: Bluetooth.discoverable ? "visibility" : "visibility_off"
                toggled: Bluetooth.discoverable
                onClicked: Bluetooth.toggleDiscoverable()
            }

            IconButton {
                icon: "sync"
                toggled: Bluetooth.isScanning
                onClicked: {
                    scanTimer.restart();
                    if (!Bluetooth.isScanning)
                        Bluetooth.startTracking();
                    Bluetooth.toggleScan();
                }
            }

            IconButton {
                icon: Bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
                toggled: Bluetooth.enabled
                onClicked: Bluetooth.toggle()
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(lists.implicitHeight, 430)
            contentHeight: lists.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: Bluetooth.enabled && Bluetooth.devices.length > 0

            ColumnLayout {
                id: lists

                width: parent.width
                spacing: 3

                StyledText {
                    Layout.leftMargin: 6
                    Layout.bottomMargin: 5
                    visible: Bluetooth.savedDevices.length > 0
                    text: "My devices"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Repeater {
                    model: Bluetooth.savedDevices

                    delegate: BluetoothDeviceRow {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        device: modelData
                        menuHost: page
                        first: index === 0
                        last: index === Bluetooth.savedDevices.length - 1
                    }
                }

                StyledText {
                    Layout.leftMargin: 6
                    Layout.topMargin: Bluetooth.savedDevices.length > 0 ? 12 : 0
                    Layout.bottomMargin: 5
                    visible: Bluetooth.nearbyDevices.length > 0
                    text: "Available"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Repeater {
                    model: Bluetooth.nearbyDevices

                    delegate: BluetoothDeviceRow {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        device: modelData
                        menuHost: page
                        first: index === 0
                        last: index === Bluetooth.nearbyDevices.length - 1
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            visible: !Bluetooth.enabled || Bluetooth.devices.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: !Bluetooth.enabled ? "Bluetooth is off" : (Bluetooth.isScanning ? "Looking for devices…" : "No devices found")
            color: Appearance.mutedColor
            font.pixelSize: 13
        }
    }
}
