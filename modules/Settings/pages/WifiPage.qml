import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

SettingsPage {
    id: page

    // network waiting for its password ("" when none)
    property string joiningSsid: ""
    property bool revealPassword: false
    property string address: ""
    // wired adapters: [{ device, state, connection, address, speed }]
    property var wired: []
    readonly property var wiredUp: wired.filter(w => w.state === "connected")

    function wiredDetails(w) {
        if (w.state === "unavailable")
            return "Cable unplugged";
        if (w.state !== "connected")
            return w.state.charAt(0).toUpperCase() + w.state.slice(1);
        const parts = ["Connected", w.address];
        if (Number(w.speed) > 0)
            parts.push(Number(w.speed) >= 1000 ? (Number(w.speed) / 1000) + " Gb/s" : w.speed + " Mb/s");
        return parts.filter(Boolean).join("  ·  ");
    }
    readonly property var otherNetworks: Network.networks.filter(n => !n.active)

    function band(frequency) {
        return frequency >= 5925 ? "6 GHz" : (frequency >= 4900 ? "5 GHz" : "2.4 GHz");
    }

    function join() {
        if (joiningSsid === "" || password.text.length === 0 || Network.connecting)
            return;
        Network.connectToNetwork(joiningSsid, password.text);
    }

    function cancelJoin() {
        joiningSsid = "";
        password.clear();
    }

    title: "Network"
    subtitle: [wiredUp.length > 0 ? "Wired" : "", Network.connected ? "Wi-Fi: " + Network.active.ssid : ""].filter(Boolean).join("  ·  ") || "Not connected"
    Component.onCompleted: {
        Network.getWifiStatus();
        Network.rescanWifi();
        addressProc.running = true;
        wiredProc.running = true;
    }

    // plugging a cable in or out shows up within a few seconds
    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: wiredProc.running = true
    }

    Process {
        id: wiredProc

        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device | while IFS=: read -r d t s c; do [ \"$t\" = ethernet ] || continue; a=$(ip -4 -o addr show dev \"$d\" | awk '{print $4}' | head -n1); p=$(cat \"/sys/class/net/$d/speed\" 2>/dev/null); echo \"$d|$s|$c|$a|$p\"; done"]
        environment: ({
            "LC_ALL": "C"
        })

        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(Boolean).map(line => {
                    const f = line.split("|");
                    return {
                        "device": f[0],
                        "state": (f[1] || "").replace(/ \(.*\)$/, ""),
                        "connection": f[2] || "",
                        "address": f[3] || "",
                        "speed": f[4] || ""
                    };
                });
                // only touch the list when something changed, so the rows do not flicker
                if (JSON.stringify(list) !== JSON.stringify(page.wired))
                    page.wired = list;
            }
        }
    }

    SettingGroup {
        title: "Wired"

        Repeater {
            model: page.wired

            delegate: SettingRow {
                required property var modelData

                icon: modelData.state === "connected" ? "lan" : "cable"
                title: "Ethernet  ·  " + modelData.device
                description: page.wiredDetails(modelData)

                StyledText {
                    visible: text !== ""
                    text: modelData.state === "connected" ? modelData.connection : ""
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                }
            }
        }

        SettingRow {
            visible: page.wired.length === 0
            icon: "cable"
            title: "No wired adapter"
            description: "Plug in an Ethernet adapter or dock to see it here"
        }
    }

    SettingGroup {
        title: "Wi-Fi"

        SettingRow {
            icon: Network.enabled ? "wifi" : "wifi_off"
            title: "Wi-Fi"
            description: !Network.enabled ? "Off" : (Network.connected ? "Connected to " + Network.active.ssid : "Not connected")

            IconButton {
                visible: Network.enabled
                toggled: Network.scanning
                icon: "sync"
                onClicked: Network.rescanWifi()
            }

            ToggleSwitch {
                checked: Network.enabled
                onToggled: Network.toggleWifi()
            }
        }
    }

    Connections {
        function onConnectionFinished(success, ssid) {
            if (success && ssid === page.joiningSsid)
                page.cancelJoin();
            addressProc.running = true;
        }

        function onActiveChanged() {
            addressProc.running = true;
        }

        target: Network
    }

    Process {
        id: addressProc

        command: ["sh", "-c", "ip -4 -o addr show scope global | awk '{print $4 \" on \" $2}' | head -n1"]

        stdout: StdioCollector {
            onStreamFinished: page.address = text.trim()
        }
    }

    SettingGroup {
        visible: Network.connected
        title: "Current network"

        SettingRow {
            icon: Network.connected ? Network.getStatusIcon(Network.active.strength) : "wifi"
            title: Network.connected ? Network.active.ssid : ""
            description: Network.connected ? ["Signal " + Network.active.strength + "%", page.band(Network.active.frequency), Network.active.security || "Open", page.address].filter(Boolean).join("  ·  ") : ""

            PillButton {
                text: "Forget"
                onClicked: Network.forgetNetwork()
            }

            PillButton {
                text: "Disconnect"
                onClicked: Network.disconnectFromNetwork()
            }
        }
    }

    SettingGroup {
        visible: page.joiningSsid !== ""
        title: "Join " + page.joiningSsid

        SettingCard {
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                FieldInput {
                    id: password

                    Layout.fillWidth: true
                    icon: "key"
                    placeholder: "Password"
                    password: !page.revealPassword
                    enabled: !Network.connecting
                    onAccepted: page.join()
                }

                IconButton {
                    icon: page.revealPassword ? "visibility_off" : "visibility"
                    onClicked: page.revealPassword = !page.revealPassword
                }

                PillButton {
                    text: "Cancel"
                    onClicked: page.cancelJoin()
                }

                PillButton {
                    toggled: true
                    enabled: password.text.length > 0 && !Network.connecting
                    text: Network.connecting ? "Connecting…" : "Connect"
                    onClicked: page.join()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: Network.connectionError !== ""
                text: Network.connectionError
                wrapMode: Text.Wrap
                color: Appearance.accentColor
                font.pixelSize: 12
            }
        }
    }

    SettingGroup {
        visible: Network.enabled
        title: "Available networks"

        Repeater {
            model: page.otherNetworks

            delegate: ListRow {
                required property var modelData

                Layout.fillWidth: true
                icon: Network.getStatusIcon(modelData.strength)
                title: modelData.ssid
                subtitle: (modelData.isSecure ? "Secured" : "Open") + "  ·  " + page.band(modelData.frequency) + (Network.connectingSsid === modelData.ssid ? "  ·  Connecting…" : "")
                trailingText: modelData.strength + "%"
                trailingIcon: modelData.isSecure ? "lock" : ""
                interactive: !Network.connecting
                active: page.joiningSsid === modelData.ssid
                onClicked: {
                    page.cancelJoin();
                    // a network that is already saved connects without asking again
                    if (modelData.isSecure && !Network.isSaved(modelData.ssid)) {
                        page.joiningSsid = modelData.ssid;
                        page.contentY = 0;
                        password.focusInput();
                    } else {
                        Network.connectToNetwork(modelData.ssid, "");
                    }
                }
            }
        }

        SettingRow {
            visible: page.otherNetworks.length === 0
            title: Network.scanning ? "Looking for networks…" : "No other networks found"
            description: Network.scanning ? "" : "Use the refresh button to scan again"
        }
    }

}
