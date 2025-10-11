import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    implicitHeight: layout.implicitHeight + 12

    Component.onCompleted: {
        console.log("NetworkPage loaded", Network.networks);
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
            spacing: 5

            Button {
                icon: "arrow_back"
                onClicked: stackView.pop()
                Layout.preferredWidth: 60
            }

            MaterialSymbol {
                icon: Network.statusIcon
                font.pixelSize: 24
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Wi-Fi"
                font.pixelSize: 24
                font.weight: Font.DemiBold
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
            }

            ToggleButton {
                toggled: Network.scanning
                icon: "sensors"
                onClicked: Network.rescanWifi()
                Layout.preferredWidth: 60
            }

            ToggleButton {
                toggled: Network.enabled
                icon: "wifi"
                Layout.preferredWidth: 60
                onClicked: Network.toggleWifi()
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
                    text: modelData.ssid
                    Layout.fillWidth: true
                    toggled: modelData.active
                    onClicked: {
                        if (!modelData.active) {
                            Network.connectToNetwork(modelData.ssid, ""); //TODO: password prompt
                        } else {
                            Network.disconnectFromNetwork();
                        }
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
