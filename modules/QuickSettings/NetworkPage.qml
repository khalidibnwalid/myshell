import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    implicitHeight: layout.implicitHeight + 32
    Component.onCompleted: Network.rescanWifi()

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 14

        PageHeader {
            Layout.fillWidth: true
            title: "Wi-Fi"
            subtitle: !Network.enabled ? "Off" : (Network.connected ? Network.active.ssid : "Not connected")
            onBack: stackView.pop()

            IconButton {
                toggled: Network.scanning
                icon: "sync"
                onClicked: Network.rescanWifi()
            }

            IconButton {
                toggled: Network.enabled
                icon: Network.enabled ? "wifi" : "wifi_off"
                onClicked: Network.toggleWifi()
            }
        }

        ListView {
            id: list

            model: Network.networks
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 5 * 59 - 3)
            spacing: 3
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            //TODO: password prompt
            delegate: ListRow {
                required property var modelData
                required property int index

                width: list.width
                first: index === 0
                last: index === list.count - 1
                active: modelData.active
                title: modelData.ssid
                subtitle: modelData.active ? "Connected" : ""
                icon: Network.getStatusIcon(modelData.strength)
                trailingIcon: modelData.isSecure ? "lock" : ""
                onClicked: {
                    if (!modelData.active)
                        Network.connectToNetwork(modelData.ssid, "");
                    else
                        Network.disconnectFromNetwork();
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            visible: list.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: !Network.enabled ? "Wi-Fi is off" : (Network.scanning ? "Looking for networks…" : "No networks found")
            color: Appearance.mutedColor
            font.pixelSize: 13
        }
    }
}
