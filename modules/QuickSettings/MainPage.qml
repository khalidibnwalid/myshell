import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property var stackView
    property var networkPageComponent
    property var bluetoothPageComponent
    property var batteryPageComponent
    property string username: ""

    implicitHeight: layout.implicitHeight

    Audio {
        id: audio
    }

    Backlight {
        id: backlight
    }

    Process {
        running: true
        command: ["whoami"]

        stdout: StdioCollector {
            onStreamFinished: root.username = text.trim()
        }

    }

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 12

        // --- Header Section ---
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 0

            RowLayout {
                spacing: 12

                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    color: Appearance.accentColor

                    MaterialSymbol {
                        icon: "person"
                        color: Appearance.bgColor
                        font.pixelSize: 22
                        anchors.centerIn: parent
                    }

                }

                ColumnLayout {
                    spacing: 0

                    Text {
                        text: root.username || "User"
                        color: Appearance.fgColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: Qt.formatDateTime(new Date(), "dddd, MMMM dd")
                        color: Appearance.fgColor
                        font.pixelSize: 12
                        opacity: 0.5
                    }

                }

            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 4

                IconButton {
                    icon: "restart_alt"
                    onClicked: WindowManager.restartComputer()
                }

                IconButton {
                    icon: "power_settings_new"
                    color: Appearance.accentColor
                    onClicked: WindowManager.shutdownComputer()
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
                fillColor: "black"
                borderColor: Appearance.accentColor
                progressColor: Appearance.accentColor
                progress: Battery.percentage
                textColor: progress > 0.4 ? Appearance.bgColor : Appearance.fgColor
            }

            ToggleButton {
                toggled: false
                text: "Settings"
                icon: "settings"
                onClicked: WindowManager.toggleSettingsVisible()
                Layout.fillWidth: true
            }

        }

        Text {
            text: "Controls"
            color: Appearance.fgColor
            font.pixelSize: 14
            font.weight: Font.DemiBold
            opacity: 0.6
            Layout.topMargin: 4
            Layout.leftMargin: 4
        }

        // --- Volume Section ---
        VolumeSlider {
            vertical: false
            value: audio.volume
            onDragged: audio.setVolume(value)
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            icon: audio.volume === 0 ? "volume_mute" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
        }

        // --- Brightness Section ---
        VolumeSlider {
            vertical: false
            value: backlight.percentage
            onDragged: backlight.setBrightness(value)
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            icon: "light_mode"
        }

        // --- Calendar Section ---
        CalendarWidget {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
        }

    }

}
