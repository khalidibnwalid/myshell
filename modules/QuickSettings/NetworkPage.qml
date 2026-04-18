import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    implicitHeight: layout.implicitHeight + 12
    Component.onCompleted: {
        Network.rescanWifi();
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
                    text: "Wi-Fi"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: Appearance.fgColor
                }

                Text {
                    text: Network.connected ? Network.active.ssid : "Not connected"
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
                    toggled: Network.scanning
                    icon: "sensors"
                    onClicked: Network.rescanWifi()
                }

                IconButton {
                    toggled: Network.enabled
                    icon: "wifi"
                    onClicked: Network.toggleWifi()
                    accentColor: Appearance.accentColor
                }

            }

        }

        ListView {
            model: Network.networks
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Network.networks.length * 64, 256)
            spacing: 3
            currentIndex: -1
            clip: true

            delegate: RowLayout {
                width: parent.width
                spacing: 3

                ToggleButton {
                    //TODO: password prompt

                    text: modelData.ssid
                    Layout.fillWidth: true
                    toggled: modelData.active
                    onClicked: {
                        if (!modelData.active)
                            Network.connectToNetwork(modelData.ssid, "");
                        else
                            Network.disconnectFromNetwork();
                    }
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    icon: Network.getStatusIcon(modelData.strength)
                    endIcon: modelData.secure ? "key" : ""
                }

            }

        }

    }

}
