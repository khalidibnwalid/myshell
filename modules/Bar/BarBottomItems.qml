import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

GridLayout {
    id: root

    property var barWindow
    readonly property bool horizontal: Config.barHorizontal

    // a column on a side bar, a row on a top or bottom bar
    columns: horizontal ? -1 : 1
    rowSpacing: 8
    columnSpacing: 8

    Audio {
        id: audio
    }

    // shown while the screen is being recorded; click to stop
    MaterialSymbol {
        visible: ScreenTools.recording
        Layout.alignment: Qt.AlignCenter
        icon: "stop_circle"
        fill: 1
        font.pixelSize: 22
        color: "#ff5f5f"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: ScreenTools.stopRecording()
        }
    }

    // wifi / bluetooth / volume / battery -> open quick settings
    Item {
        Layout.alignment: Qt.AlignCenter
        implicitWidth: statusColumn.implicitWidth + (root.horizontal ? 24 : 0)
        implicitHeight: root.horizontal ? 36 : statusColumn.implicitHeight

        // top and bottom bars: the status icons share one capsule
        Rectangle {
            anchors.fill: parent
            visible: root.horizontal
            radius: height / 2
            color: Appearance.surfaceColor
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: WindowManager.toggleQuickSettingsVisible()
        }

        GridLayout {
            id: statusColumn

            anchors.centerIn: parent
            columns: root.horizontal ? -1 : 1
            rowSpacing: 8
            columnSpacing: root.horizontal ? 12 : 8

        // shown only while an app listens to the microphone; a click mutes or unmutes it
        MaterialSymbol {
            id: micIcon

            visible: audio.micInUse
            Layout.alignment: Qt.AlignCenter
            icon: audio.micMuted ? "mic_off" : "mic"
            fill: audio.micMuted ? 0 : 1
            font.pixelSize: 22
            color: audio.micMuted ? Appearance.mutedColor : "#ff8a5c"
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: (audio.micMuted ? "Unmute the microphone" : "Mute the microphone") + ", used by " + audio.micUsers
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    audio.toggleMicMute();
                    event.accepted = true;
                }
            }

            MouseArea {
                id: micArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: audio.toggleMicMute()
            }

            FocusRing {
                radius: height / 2
            }
        }

        MaterialSymbol {
            Layout.alignment: Qt.AlignCenter
            icon: Network.statusIcon
            font.pixelSize: 22
            color: Appearance.fgColor
        }

        MaterialSymbol {
            visible: Bluetooth.enabled
            Layout.alignment: Qt.AlignCenter
            icon: Bluetooth.statusIcon
            font.pixelSize: 22
            color: Appearance.fgColor
        }

        MaterialSymbol {
            id: volumeIcon

            Layout.alignment: Qt.AlignCenter
            icon: audio.mute || audio.volume === 0 ? "volume_off" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
            font.pixelSize: 22
            color: Appearance.fgColor

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: volumePopup.show(volumeIcon.mapToItem(null, volumeIcon.width / 2, volumeIcon.height / 2))
                onExited: volumePopup.hideLater()
                onClicked: WindowManager.toggleQuickSettingsVisible()
            }
        }

        // keyboard layout: hover for the switcher, click for quick settings like the other status icons
        StyledText {
            id: layoutLabel

            Layout.alignment: Qt.AlignCenter
            text: Keyboard.layout
            color: Appearance.fgColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
            opacity: layoutArea.containsMouse ? 1 : 0.8

            MouseArea {
                id: layoutArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: layoutPopup.show(layoutLabel.mapToItem(null, layoutLabel.width / 2, layoutLabel.height / 2))
                onExited: layoutPopup.hideLater()
                onClicked: WindowManager.toggleQuickSettingsVisible()
            }
        }

        GridLayout {
            visible: Battery.device.isLaptopBattery
            Layout.alignment: Qt.AlignCenter
            columns: root.horizontal ? 2 : 1
            rowSpacing: -2
            columnSpacing: 2

            MaterialSymbol {
                Layout.alignment: Qt.AlignCenter
                icon: Battery.iconName
                font.pixelSize: 22
                fill: Battery.percentage
                color: Appearance.fgColor
            }

            StyledText {
                Layout.alignment: Qt.AlignCenter
                text: Math.round(Battery.percentage * 100)
                color: Appearance.mutedColor
                font.pixelSize: 11
            }
        }

        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignCenter
        implicitWidth: root.horizontal ? 36 : 22
        implicitHeight: root.horizontal ? 36 : 22
        radius: height / 2
        color: root.horizontal && powerArea.containsMouse ? Appearance.surfaceHighColor : (root.horizontal ? Appearance.surfaceColor : "transparent")

        MaterialSymbol {
            anchors.centerIn: parent
            icon: "power_settings_new"
            font.pixelSize: 22
            color: Appearance.fgColor
        }

        MouseArea {
            id: powerArea

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: WindowManager.toggleQuickSettingsVisible()
        }
    }

    VolumePopup {
        id: volumePopup
        barWindow: root.barWindow
    }

    LayoutPopup {
        id: layoutPopup
        barWindow: root.barWindow
    }
}
