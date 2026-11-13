import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    function deviceIcon(name) {
        const icon = (name || "").toLowerCase();
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
        if (icon.includes("phone"))
            return "smartphone";
        return "devices_other";
    }

    implicitHeight: layout.implicitHeight + 32
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
            subtitle: !Bluetooth.enabled ? "Off" : (Bluetooth.connectedDevices.length ? Bluetooth.connectedDevices[0].name : (Bluetooth.isScanning ? "Scanning…" : "On"))
            onBack: stackView.pop()

            IconButton {
                icon: "sync"
                toggled: Bluetooth.isScanning
                onClicked: Bluetooth.toggleScan()
            }

            IconButton {
                icon: Bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
                toggled: Bluetooth.enabled
                onClicked: Bluetooth.toggle()
            }
        }

        ListView {
            id: list

            model: Bluetooth.devices
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 5 * 59 - 3)
            spacing: 3
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: ListRow {
                required property var modelData
                required property int index

                width: list.width
                first: index === 0
                last: index === list.count - 1
                active: modelData.connected
                title: modelData.name
                subtitle: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "")
                icon: deviceIcon(modelData.icon)
                trailingText: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                onClicked: modelData.connected = !modelData.connected
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            visible: list.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: !Bluetooth.enabled ? "Bluetooth is off" : (Bluetooth.isScanning ? "Looking for devices…" : "No devices found")
            color: Appearance.mutedColor
            font.pixelSize: 13
        }
    }
}
