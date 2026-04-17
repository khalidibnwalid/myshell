import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var stackView
    property var networkPageComponent
    property var bluetoothPageComponent
    property var batteryPageComponent

    implicitHeight: layout.implicitHeight

    Audio {
        id: audio
    }

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 12

        // --- Header Section ---
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 0

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Quick Settings"
                    color: Appearance.fgColor
                    font.pixelSize: 20
                    font.bold: true
                }

                Text {
                    text: Qt.formatDateTime(new Date(), "dddd, MMMM dd")
                    color: Appearance.fgColor
                    font.pixelSize: 12
                    opacity: 0.5
                }

            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 4

                // Restart Ghost Button
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: "transparent"

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: "restart_alt"
                        font.pixelSize: 22
                        color: Appearance.fgColor
                        opacity: restartMA.containsMouse ? 1 : 0.4
                    }

                    MouseArea {
                        id: restartMA

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WindowManager.restartComputer()
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.fgColor
                        opacity: restartMA.containsMouse ? 0.1 : 0
                    }

                }

                // Shutdown Ghost Button
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: "transparent"

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: "power_settings_new"
                        font.pixelSize: 22
                        color: Appearance.accentColor
                        opacity: shutdownMA.containsMouse ? 1 : 0.6
                    }

                    MouseArea {
                        id: shutdownMA

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WindowManager.shutdownComputer()
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.accentColor
                        opacity: shutdownMA.containsMouse ? 0.1 : 0
                    }

                }

            }

        }

        // --- Grid Section ---
        GridLayout {
            id: contentGrid

            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            Layout.fillWidth: true

            ToggleButton {
                toggled: Network.enabled
                text: Network.connected ? Network.active.ssid : (Network.enabled ? "Available" : "Disabled")
                icon: Network.statusIcon
                endIcon: "arrow_forward_ios"
                onClicked: stackView.push(networkPageComponent, {
                    "stackView": stackView
                })
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            ToggleButton {
                toggled: Bluetooth.enabled
                text: Bluetooth.connectedDevices.length ? Bluetooth.connectedDevices[0].name : "Bluetooth"
                icon: Bluetooth.statusIcon
                endIcon: "arrow_forward_ios"
                onClicked: stackView.push(bluetoothPageComponent, {
                    "stackView": stackView
                })
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            Button {
                text: "Battery " + Math.round(Battery.percentage * 100) + "%"
                icon: Battery.activeProfileIcon
                endIcon: "arrow_forward_ios"
                onClicked: stackView.push(batteryPageComponent, {
                    "stackView": stackView
                })
                Layout.fillWidth: true
                fillColor: Appearance.highlightColor
                textColor: Appearance.fgColor
            }

            ToggleButton {
                toggled: false
                text: "Settings"
                icon: "settings"
                onClicked: WindowManager.toggleSettingsVisible()
                Layout.fillWidth: true
            }

        }

        // --- Volume Section ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4

                Text {
                    text: "Volume"
                    color: Appearance.fgColor
                    font.pixelSize: 13
                    font.bold: true
                    opacity: 0.5
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Math.round(Math.min(audio.volume, 1) * 100) + "%"
                    color: Appearance.accentColor
                    font.pixelSize: 13
                    font.bold: true
                }

            }

            VolumeSlider {
                vertical: false
                value: audio.volume
                onDragged: audio.setVolume(value)
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                icon: audio.volume === 0 ? "volume_mute" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
            }

        }

        // --- Calendar Section ---
        CalendarWidget {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
        }

    }

}
