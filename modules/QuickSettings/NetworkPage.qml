import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Controls
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

            delegate: Item {
                id: entry

                required property var modelData
                required property int index

                width: list.width
                implicitHeight: 56

                ListRow {
                    anchors.fill: parent
                    first: entry.index === 0
                    last: entry.index === list.count - 1
                    active: entry.modelData.active
                    title: entry.modelData.ssid
                    subtitle: entry.modelData.active ? "Connected" : (entry.modelData.isSecure ? "Secured" : "Open network")
                    icon: Network.getStatusIcon(entry.modelData.strength)
                    trailingSpace: 36
                    interactive: !Network.connecting
                    onClicked: {
                        if (entry.modelData.active) {
                            Network.disconnectFromNetwork();
                        } else if (entry.modelData.isSecure && !Network.isSaved(entry.modelData.ssid)) {
                            stackView.push(passwordPage, {
                                "accessPoint": entry.modelData,
                                "stackView": stackView
                            });
                        } else {
                            Network.connectToNetwork(entry.modelData.ssid, "");
                        }
                    }
                }

                // context menu
                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    iconSize: 20
                    icon: "more_vert"
                    color: entry.modelData.active ? Appearance.accentContrastColor : Appearance.fgColor
                    onClicked: menu.opened ? menu.close() : menu.open()

                    Popup {
                        id: menu

                        x: parent.width - width
                        y: parent.height + 4
                        padding: 6
                        margins: 8

                        background: Rectangle {
                            radius: 18
                            color: Qt.tint(Appearance.bgColor, Qt.alpha(Appearance.fgColor, 0.1))
                            border.width: 1
                            border.color: Appearance.outlineColor
                        }

                        contentItem: ColumnLayout {
                            spacing: 2

                            Repeater {
                                model: entry.modelData.active ? [
                                    {
                                        "label": "Disconnect",
                                        "icon": "wifi_off"
                                    },
                                    {
                                        "label": "Forget network",
                                        "icon": "delete"
                                    }
                                ] : [
                                    {
                                        "label": "Forget network",
                                        "icon": "delete"
                                    }
                                ]

                                delegate: Rectangle {
                                    id: item

                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitWidth: 190
                                    implicitHeight: 40
                                    radius: 14
                                    color: itemArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        MaterialSymbol {
                                            icon: item.modelData.icon
                                            font.pixelSize: 18
                                            color: Appearance.fgColor
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: item.modelData.label
                                        }
                                    }

                                    MouseArea {
                                        id: itemArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            menu.close();
                                            if (item.modelData.label === "Disconnect")
                                                Network.disconnectFromNetwork();
                                            else
                                                Network.forgetNetwork(entry.modelData.ssid);
                                        }
                                    }
                                }
                            }
                        }
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
