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
        implicitWidth: statusColumn.implicitWidth
        implicitHeight: statusColumn.implicitHeight

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: WindowManager.toggleQuickSettingsVisible()
        }

        GridLayout {
            id: statusColumn
            columns: root.horizontal ? -1 : 1
            rowSpacing: 8
            columnSpacing: 8

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

        ColumnLayout {
            visible: Battery.device.isLaptopBattery
            Layout.alignment: Qt.AlignCenter
            spacing: -2

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

    MaterialSymbol {
        Layout.alignment: Qt.AlignCenter
        icon: "power_settings_new"
        font.pixelSize: 22
        color: Appearance.fgColor

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
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
