pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Scope {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available ? adapter.state === BluetoothAdapterState.Enabled : false
    readonly property bool isScanning: available ? adapter.discovering : false
    readonly property bool discoverable: available ? adapter.discoverable : false

    readonly property var allDevices: adapter?.devices?.values ?? []
    readonly property var connectedDevices: allDevices.filter(d => d.connected)
    readonly property bool connected: connectedDevices.length > 0
    property string contextMenuAddress: ""

    // --- ordering ---------------------------------------------------------
    // Signal strength comes from bluez (it is only reported while scanning).
    property var rssi: ({}) // address -> dBm
    // Display order: sorted strongest-first when the page opens, devices found
    // later are appended, so the list never reshuffles under the pointer.
    property var order: []
    property bool tracking: false
    property bool needsSort: false

    // One entry per device name (bluez often lists a device twice, e.g. classic + LE),
    // unnamed unpaired devices hidden, in display order.
    readonly property var devices: {
        const best = {};
        for (const d of allDevices) {
            const known = d.paired || d.connected;
            if (!known && !isNamed(d))
                continue;
            const key = (d.name || d.address).toLowerCase();
            if (!best[key] || rank(d) > rank(best[key]))
                best[key] = d;
        }
        const pos = a => {
            const i = order.indexOf(a);
            return i < 0 ? order.length : i;
        };
        return Object.values(best).sort((a, b) => pos(a.address) - pos(b.address));
    }
    // paired or connected: connected first, then the display order
    readonly property var savedDevices: devices.filter(d => d.paired || d.connected).sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0))
    readonly property var nearbyDevices: devices.filter(d => !d.paired && !d.connected)

    property string statusIcon: {
        if (!enabled || !available)
            return "bluetooth_disabled";
        if (connected)
            return "bluetooth_connected";
        return "bluetooth";
    }

    function isNamed(d) {
        return !!d.name && !/^([0-9A-F]{2}[-:_]){5}[0-9A-F]{2}$/i.test(d.name);
    }

    function strength(d) {
        const v = rssi[d.address];
        return v === undefined ? -200 : v;
    }

    // which duplicate to keep: connected > paired > strongest signal
    function rank(d) {
        return (d.connected ? 2000 : 0) + (d.paired ? 1000 : 0) + (strength(d) + 200);
    }

    // signal bars for a device, "" when unknown
    function signalIcon(d) {
        const v = rssi[d.address];
        if (v === undefined)
            return "";
        if (v >= -60)
            return "signal_cellular_4_bar";
        if (v >= -72)
            return "signal_cellular_3_bar";
        if (v >= -84)
            return "signal_cellular_2_bar";
        return "signal_cellular_1_bar";
    }

    function syncOrder() {
        const addresses = allDevices.map(d => d.address);
        const byStrength = (a, b) => (rssi[b] ?? -200) - (rssi[a] ?? -200);
        if (needsSort) {
            needsSort = false;
            order = addresses.slice().sort(byStrength);
            return;
        }
        const kept = order.filter(a => addresses.includes(a));
        const added = addresses.filter(a => !kept.includes(a)).sort(byStrength);
        if (added.length > 0 || kept.length !== order.length)
            order = kept.concat(added);
    }

    // called by the Bluetooth page while it is open
    function startTracking() {
        tracking = true;
        needsSort = true;
        rssiProc.running = true;
    }

    function stopTracking() {
        tracking = false;
    }

    // --- adapter ------------------------------------------------------------
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

    function toggleDiscoverable() {
        if (!available || !enabled)
            return;
        adapter.discoverable = !adapter.discoverable;
    }

    // --- devices ------------------------------------------------------------
    function stateText(d) {
        if (d.pairing)
            return "Pairing…";
        switch (d.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting…";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting…";
        case BluetoothDeviceState.Connected:
            return "Connected";
        }
        if (d.blocked)
            return "Blocked";
        if (d.paired)
            return d.trusted ? "Paired" : "Paired · not trusted";
        return "";
    }

    function isBusy(d) {
        return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting;
    }

    // the obvious next step for a device: pair -> connect -> disconnect
    function primaryAction(d) {
        if (d.pairing)
            d.cancelPair();
        else if (d.connected)
            d.disconnect();
        else if (d.paired)
            connectDevice(d);
        else
            pairDevice(d);
    }

    function connectDevice(d) {
        if (d.blocked)
            d.blocked = false;
        d.connect();
    }

    // pair, then trust and connect once pairing succeeds
    function pairDevice(d) {
        pendingPair = d.address;
        d.pair();
    }

    function forget(d) {
        if (pendingPair === d.address)
            pendingPair = "";
        closeContextMenu();
        d.forget();
    }

    function toggleContextMenu(d) {
        contextMenuAddress = contextMenuAddress === d.address ? "" : d.address;
    }

    function closeContextMenu() {
        contextMenuAddress = "";
    }

    property string pendingPair: ""

    Timer {
        // finish the pair -> trust -> connect chain
        interval: 500
        repeat: true
        running: root.pendingPair !== ""
        onTriggered: {
            const d = root.allDevices.find(x => x.address === root.pendingPair);
            if (!d || (!d.pairing && !d.paired)) {
                root.pendingPair = "";
            } else if (d.paired) {
                root.pendingPair = "";
                d.trusted = true;
                d.connect();
            }
        }
    }

    onAllDevicesChanged: syncOrder()

    Timer {
        interval: 2500
        repeat: true
        running: root.tracking && root.enabled
        onTriggered: rssiProc.running = true
    }

    Process {
        id: rssiProc

        command: ["busctl", "--system", "--json=short", "call", "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const objects = JSON.parse(this.text).data[0];
                    const next = {};
                    for (const path in objects) {
                        const dev = objects[path]["org.bluez.Device1"];
                        if (dev && dev.RSSI && dev.Address)
                            next[dev.Address.data] = dev.RSSI.data;
                    }
                    root.rssi = next;
                } catch (e) {}
                root.syncOrder();
            }
        }
    }
}
