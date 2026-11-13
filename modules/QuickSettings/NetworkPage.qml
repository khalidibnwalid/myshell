import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    implicitHeight: layout.implicitHeight + 32
    Component.onCompleted: {
        Network.getWifiStatus();
        Network.rescanWifi();
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

        StyledText {
            Layout.fillWidth: true
            visible: Network.connectionError !== ""
            text: Network.connectionError
            color: Appearance.accentColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        ListView {
            id: list

            model: Network.networks
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
                active: modelData.active
                title: modelData.ssid
                subtitle: modelData.active ? "Connected" : (modelData.isSecure ? "Secured" : "Open network")
                icon: Network.getStatusIcon(modelData.strength)
                trailingIcon: modelData.isSecure ? "lock" : ""
                interactive: !Network.connecting
                onClicked: {
                    if (modelData.active) {
                        Network.disconnectFromNetwork();
                    } else if (modelData.isSecure) {
                        stackView.push(passwordPage, {
                            "accessPoint": modelData,
                            "stackView": stackView
                        });
                    } else {
                        Network.connectToNetwork(modelData.ssid, "");
                    }
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

    Component {
        id: passwordPage

        WifiPasswordPage {
        }
    }
}
