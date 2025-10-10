import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    implicitHeight: layout.implicitHeight + 12

    ColumnLayout {
        id: layout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Button {
                icon: "arrow_back"
                onClicked: stackView.pop()
                Layout.preferredWidth: 60
            }

            MaterialSymbol {
                icon: Bluetooth.statusIcon
                font.pixelSize: 24
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Bluetooth"
                font.pixelSize: 24
                font.weight: Font.DemiBold
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
            }

            ToggleButton {
                icon: "sensors"
                Layout.preferredWidth: 60
                toggled: Bluetooth.isScanning
                onClicked: Bluetooth.toggleScan()
            }

            ToggleButton {
                icon: "bluetooth"
                Layout.preferredWidth: 60
                toggled: Bluetooth.enabled
                onClicked: Bluetooth.toggle()
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
