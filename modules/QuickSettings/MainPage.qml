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

    implicitHeight: layout.implicitHeight + 32

    Audio {
        id: audio
    }

    Backlight {
        id: backlight
    }

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12

        // --- Clock header ---
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.topMargin: 4
            Layout.bottomMargin: 2

            StyledText {
                text: Time.format("HH:mm")
                font.pixelSize: 32
                font.weight: Font.Bold
                font.letterSpacing: -0.5
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: Time.format("ddd, d MMM")
                color: Appearance.mutedColor
                font.pixelSize: 13
            }
        }

        // --- Brightness ---
        PillSlider {
            Layout.fillWidth: true
            icon: "light_mode"
            value: backlight.percentage
            onDragged: v => backlight.setBrightness(v)
        }

        // --- Volume ---
        PillSlider {
            Layout.fillWidth: true
            icon: audio.mute || audio.volume === 0 ? "volume_off" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
            value: audio.volume
            onDragged: v => audio.setVolume(v)
        }

        // --- Media ---
        MediaCard {
            Layout.fillWidth: true
        }

        // --- Tiles ---
        GridLayout {
            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            Layout.fillWidth: true

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                toggled: Network.enabled
                text: Network.connected ? Network.active.ssid : (Network.enabled ? "Wi-Fi" : "Wi-Fi off")
                icon: Network.statusIcon
                onClicked: stackView.push(networkPageComponent, {
                    "stackView": stackView
                })
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                toggled: Bluetooth.enabled
                text: Bluetooth.connectedDevices.length ? Bluetooth.connectedDevices[0].name : "Bluetooth"
                icon: Bluetooth.statusIcon
                onClicked: stackView.push(bluetoothPageComponent, {
                    "stackView": stackView
                })
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                toggled: NotificationService.dnd
                text: "Do not disturb"
                icon: "do_not_disturb_on"
                onClicked: NotificationService.dnd = !NotificationService.dnd
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                toggled: audio.mute
                text: audio.mute ? "Muted" : "Mute"
                icon: audio.mute ? "volume_off" : "volume_up"
                onClicked: audio.setMute(!audio.mute)
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                toggled: true
                text: "Battery " + Math.round(Battery.percentage * 100) + "%"
                icon: Battery.activeProfileIcon
                onClicked: stackView.push(batteryPageComponent, {
                    "stackView": stackView
                })
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                toggled: false
                text: Keyboard.layout
                icon: "keyboard"
            }
        }

        // --- Bottom actions ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    {
                        "icon": "restart_alt",
                        "action": () => WindowManager.restartComputer()
                    },
                    {
                        "icon": "settings",
                        "action": () => WindowManager.toggleSettingsVisible()
                    },
                    {
                        "icon": "power_settings_new",
                        "action": () => WindowManager.shutdownComputer()
                    }
                ]

                delegate: Rectangle {
                    id: actionBtn

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 40
                    radius: 20
                    color: ma.containsMouse ? Appearance.surfaceColor : "transparent"
                    border.width: 1
                    border.color: Appearance.outlineColor
                    scale: ma.pressed ? 0.97 : 1

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: actionBtn.modelData.icon
                        font.pixelSize: 18
                        color: Appearance.fgColor
                    }

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: actionBtn.modelData.action()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }
            }
        }
    }
}
