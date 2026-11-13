import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page

    function deviceDetails(d) {
        const parts = [Bluetooth.stateText(d)];
        if (d.batteryAvailable)
            parts.push("Battery " + Math.round(d.battery * 100) + "%");
        return parts.filter(Boolean).join("  ·  ");
    }

    title: "Bluetooth"
    subtitle: !Bluetooth.available ? "No adapter found" : (!Bluetooth.enabled ? "Off" : (Bluetooth.connected ? Bluetooth.connectedDevices.length + " connected" : "On"))
    Component.onCompleted: Bluetooth.startTracking()
    Component.onDestruction: {
        Bluetooth.stopTracking();
        if (Bluetooth.isScanning)
            Bluetooth.toggleScan();
    }

    headerActions: [
        ToggleSwitch {
            enabled: Bluetooth.available
            checked: Bluetooth.enabled
            onToggled: Bluetooth.toggle()
        }
    ]

    SettingGroup {
        visible: Bluetooth.enabled

        SettingRow {
            icon: "visibility"
            title: "Visible to other devices"
            description: "Lets nearby devices find and pair with " + (Bluetooth.adapter?.name || "this computer")

            ToggleSwitch {
                checked: Bluetooth.discoverable
                onToggled: Bluetooth.toggleDiscoverable()
            }
        }

        SettingRow {
            icon: "bluetooth_searching"
            title: "Search for devices"
            description: Bluetooth.isScanning ? "Searching… put the device in pairing mode" : "Scan for devices that are ready to pair"

            PillButton {
                toggled: Bluetooth.isScanning
                text: Bluetooth.isScanning ? "Stop" : "Scan"
                onClicked: Bluetooth.toggleScan()
            }
        }
    }

    SettingGroup {
        visible: Bluetooth.enabled && Bluetooth.savedDevices.length > 0
        title: "My devices"

        Repeater {
            model: Bluetooth.savedDevices

            delegate: SettingRow {
                id: saved

                required property var modelData

                icon: modelData.connected ? "bluetooth_connected" : "bluetooth"
                title: modelData.name || modelData.address
                description: page.deviceDetails(modelData)

                PillButton {
                    toggled: saved.modelData.connected
                    enabled: !Bluetooth.isBusy(saved.modelData)
                    text: saved.modelData.connected ? "Disconnect" : "Connect"
                    onClicked: Bluetooth.primaryAction(saved.modelData)
                }

                IconButton {
                    icon: "delete"
                    onClicked: Bluetooth.forget(saved.modelData)
                }
            }
        }
    }

    SettingGroup {
        visible: Bluetooth.enabled
        title: "Nearby devices"

        Repeater {
            model: Bluetooth.nearbyDevices

            delegate: SettingRow {
                id: nearby

                required property var modelData

                icon: Bluetooth.signalIcon(modelData) || "bluetooth"
                title: modelData.name || modelData.address
                description: Bluetooth.stateText(modelData) || modelData.address

                PillButton {
                    text: nearby.modelData.pairing ? "Cancel" : "Pair"
                    onClicked: Bluetooth.primaryAction(nearby.modelData)
                }
            }
        }

        SettingRow {
            visible: Bluetooth.nearbyDevices.length === 0
            title: Bluetooth.isScanning ? "Searching for devices…" : "No new devices found"
            description: Bluetooth.isScanning ? "" : "Press Scan to look for devices in pairing mode"
        }
    }

    SettingGroup {
        visible: !Bluetooth.enabled

        SettingRow {
            icon: "bluetooth_disabled"
            title: Bluetooth.available ? "Bluetooth is off" : "No Bluetooth adapter"
            description: Bluetooth.available ? "Turn it on to connect headphones, keyboards and other devices" : "Check that the bluetooth service is running"
        }
    }
}
