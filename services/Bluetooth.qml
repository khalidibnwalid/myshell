pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Scope {
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available ? adapter.state === BluetoothAdapterState.Enabled : false

    readonly property var connectedDevices: adapter?.devices?.values.filter(d => d.connected) || []
    readonly property var devices: adapter?.devices?.values
    readonly property bool connected: connectedDevices.length > 0

    readonly property bool isScanning: available ? adapter.discovering : false

    property string statusIcon: {
        if (!enabled || !available) {
            return "bluetooth_disabled";
        }

        if (connected) {
            return "bluetooth_connected";
        }

        return "bluetooth";
    }

    function toggle() {
        if (!available)
            return;

        adapter.enabled = !enabled;
    }

    function toggleScan() {
        if (!available || !enabled)
            return;

        adapter.discovering = !adapter.discovering;
    }
}
