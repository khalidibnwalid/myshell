import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    spacing: 14

    Audio {
        id: audio
    }

    // wifi / bluetooth / volume / battery -> open quick settings
    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: statusColumn.implicitWidth
        implicitHeight: statusColumn.implicitHeight

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: WindowManager.toggleQuickSettingsVisible()
        }

        ColumnLayout {
            id: statusColumn
            spacing: 14

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            icon: Network.statusIcon
            font.pixelSize: 22
            color: Appearance.fgColor
        }

        MaterialSymbol {
            visible: Bluetooth.enabled
            Layout.alignment: Qt.AlignHCenter
            icon: Bluetooth.statusIcon
            font.pixelSize: 22
            color: Appearance.fgColor
        }

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            icon: audio.mute || audio.volume === 0 ? "volume_off" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
            font.pixelSize: 22
            color: Appearance.fgColor
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Keyboard.layout
            color: Appearance.fgColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
            opacity: 0.8
        }

        ColumnLayout {
            visible: Battery.device.isLaptopBattery
            Layout.alignment: Qt.AlignHCenter
            spacing: -2

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                icon: Battery.iconName
                font.pixelSize: 22
                fill: Battery.percentage
                color: Appearance.fgColor
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Math.round(Battery.percentage * 100)
                color: Appearance.mutedColor
                font.pixelSize: 11
            }
        }

        }
    }

    MaterialSymbol {
        Layout.alignment: Qt.AlignHCenter
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
}
