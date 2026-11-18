import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var stackView
    property var networkPageComponent
    property var bluetoothPageComponent
    property var batteryPageComponent
    property var audioPageComponent
    property var calendarPageComponent
    property var appsPageComponent

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
                text: Time.format(Config.bar.clock24h ? "HH:mm" : "hh:mm AP")
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

            IconButton {
                size: 34
                iconSize: 19
                icon: "apps"
                Accessible.name: "All apps"
                ToolTip.visible: hovered
                ToolTip.text: "All apps"
                onClicked: stackView.push(appsPageComponent, {
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
                onClicked: {
                    WindowManager.quickSettingsVisible = false;
                    Apps.open("processes");
                }
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: SystemInfo.cpuCores > 0 ? SystemInfo.cpuCores + " cores" + (SystemInfo.cpuTemperature >= 0 ? " · " + Math.round(SystemInfo.cpuTemperature) + "°C" : "") : "—"
                icon: "developer_board"
                // the System page with every reading
                onClicked: {
                    WindowManager.quickSettingsVisible = false;
                    WindowManager.settingsDetailed = true;
                    WindowManager.openSettings("system");
                }
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: SystemInfo.formatCapacityRatio(SystemInfo.diskUsed, SystemInfo.diskTotal)
                icon: "storage"
                onClicked: {
                    WindowManager.quickSettingsVisible = false;
                    WindowManager.openSettings("storage");
                }
            }

        }

        // --- Actions: screen utilities on the left, system on the right, in one pill ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: 27
            color: Appearance.surfaceColor

            Component {
                id: actionButton

                Item {
                    id: btn

                    required property var modelData
                    readonly property bool live: (!!modelData.record && ScreenTools.recording) || (!!modelData.pause && WindowManager.idlePauseRemainingSeconds > 0)

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Accessible.name: modelData.name
                    ToolTip.visible: btnArea.containsMouse
                    ToolTip.text: modelData.pause && WindowManager.idlePauseRemainingSeconds > 0
                        ? "Resume auto-lock (" + Math.ceil(WindowManager.idlePauseRemainingSeconds / 60) + " min left)"
                        : modelData.name

                    Rectangle {
                        anchors.centerIn: parent
                        width: 42
                        height: 42
                        radius: 21
                        color: btn.live ? (btn.modelData.pause ? Appearance.accentColor : "#ff5f5f") : (btnArea.containsMouse ? Appearance.surfaceHighColor : "transparent")
                        scale: btnArea.pressed ? 0.92 : 1

                        MaterialSymbol {
                            anchors.centerIn: parent
                            icon: btn.modelData.pause && btn.live ? "lock_clock" : (btn.live ? "stop" : btn.modelData.icon)
                            fill: btn.live ? 1 : 0
                            font.pixelSize: 20
                            color: btn.live ? Appearance.bgColor : Appearance.fgColor
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

                    MouseArea {
                        id: btnArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btn.modelData.action()
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 0

                Repeater {
                    model: [
                        {
                            "icon": "colorize",
                            "name": "Pick a colour",
                            "action": () => ScreenTools.pickColor()
                        },
                        {
                            "icon": "screenshot_region",
                            "name": "Screenshot",
                            "action": () => ScreenTools.screenshot()
                        },
                        {
                            "icon": "videocam",
                            "name": "Record screen",
                            "record": true,
                            "action": () => ScreenTools.toggleRecording()
                        }
                    ]
                    delegate: actionButton
                }

                Rectangle {
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    implicitWidth: 1
                    implicitHeight: 22
                    color: Appearance.outlineColor
                }

                Repeater {
                    model: [
                        {
                            "icon": WindowManager.idlePauseRemainingSeconds > 0 ? "lock_clock" : "bedtime_off",
                            "name": WindowManager.idlePauseRemainingSeconds > 0 ? "Resume auto-lock" : "Pause auto-lock for one hour",
                            "pause": true,
                            "action": () => WindowManager.toggleIdlePause()
                        },
                        {
                            "icon": "settings",
                            "name": "Settings",
                            "action": () => {
                                WindowManager.quickSettingsVisible = false;
                                WindowManager.toggleSettingsVisible();
                            }
                        },
                        {
                            "icon": "restart_alt",
                            "name": "Restart",
                            "action": () => WindowManager.restartComputer()
                        },
                        {
                            "icon": "power_settings_new",
                            "name": "Shut down",
                            "action": () => WindowManager.shutdownComputer()
                        }
                    ]
                    delegate: actionButton
                }
            }
        }
    }
}
