import "../../components/"
import "../../config/"
import "../../services/"
import "./BarClock.qml"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    Layout.fillWidth: true
    width: parent.width

    // background
    Rectangle {
        anchors.fill: parent
        color: Appearance.bgColor
        radius: 16
        border.color: Appearance.borderColor
        border.width: 2

        MouseArea {
            anchors.fill: parent
            onClicked: WindowManager.setQuickSettingsVisible(!WindowManager.quickSettingsVisible)
            cursorShape: Qt.PointingHandCursor
        }

    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        Layout.bottomMargin: 8

        MaterialSymbol {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            icon: Network.statusIcon
            font.pixelSize: 24
            color: Appearance.fgColor
        }

        MaterialSymbol {
            visible: Bluetooth.enabled
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            icon: Bluetooth.statusIcon
            font.pixelSize: 24
            color: Appearance.fgColor
        }

        MaterialSymbol {
            visible: Battery.device.isLaptopBattery
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            icon: Battery.iconName
            font.pixelSize: 24
            fill: Battery.percentage
            color: Appearance.fgColor
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.fgColor
            font.pixelSize: 14
            font.family: "Monospace"
            font.weight: Font.DemiBold
            text: Keyboard.layout
            opacity: 0.8
            Layout.bottomMargin: 4
        }

        BarClock {
            Layout.fillWidth: true
        }

    }

}
