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
    property var audioPageComponent
    property var calendarPageComponent

    implicitHeight: layout.implicitHeight + 32

    Audio {
        id: audio
    }

    Connections {
        target: WindowManager
        function onQuickSettingsVisibleChanged() {
            if (WindowManager.quickSettingsVisible)
                SystemInfo.refresh();
        }
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
                text: Time.format("hh:mm AP")
                font.pixelSize: 32
                font.weight: Font.Bold
                font.letterSpacing: -0.5
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: Time.format("ddd, d MMM yyyy")
                color: Appearance.mutedColor
                font.pixelSize: 13
            }

            IconButton {
                size: 34
                iconSize: 19
                icon: "calendar_month"
                onClicked: stackView.push(calendarPageComponent, {
                    "stackView": stackView
                })
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
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48

            PillSlider {
                id: volumeSlider

                anchors.fill: parent
                iconRightMargin: audio.volume > 0.85 && (volumeSlider.hovered || deviceButton.hovered) ? 50 : 14
                icon: audio.mute || audio.volume === 0 ? "volume_off" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
                value: audio.volume
                onDragged: v => audio.setVolume(v)
            }

            Rectangle {
                id: deviceButton

                property bool hovered: deviceArea.containsMouse

                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                radius: 19
                color: hovered ? Appearance.surfaceHighColor : Appearance.surfaceColor
                opacity: volumeSlider.hovered || hovered ? 1 : 0
                Accessible.name: "Audio devices"

                MaterialSymbol {
                    anchors.centerIn: parent
                    icon: "speaker"
                    font.pixelSize: 19
                    color: Appearance.fgColor
                }

                MouseArea {
                    id: deviceArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stackView.push(audioPageComponent, {
                        "stackView": stackView
                    })
                }

                Behavior on opacity {
                    NumberAnimation { duration: Appearance.animFast }
                }

                Behavior on color {
                    ColorAnimation { duration: Appearance.animFast }
                }
            }
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
                text: SystemInfo.formatCapacityRatio(SystemInfo.memoryUsed, SystemInfo.memoryTotal)
                icon: "memory"
                onClicked: SystemInfo.refresh()
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: SystemInfo.cpuCores > 0 ? SystemInfo.cpuCores + " cores" + (SystemInfo.cpuTemperature >= 0 ? " · " + Math.round(SystemInfo.cpuTemperature) + "°C" : "") : "—"
                icon: "developer_board"
                onClicked: SystemInfo.refresh()
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: SystemInfo.formatCapacityRatio(SystemInfo.diskUsed, SystemInfo.diskTotal)
                icon: "storage"
                onClicked: SystemInfo.refresh()
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
