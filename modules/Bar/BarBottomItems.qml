import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../components/"
import "../../config/"
import "../../services/"
import "./BarClock.qml"

ColumnLayout {
    anchors {
        left: parent.left
        right: parent.right
    }

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
        anchors.horizontalCenter: parent.horizontalCenter
        Layout.topMargin: 8
        Layout.bottomMargin: 8

        MaterialSymbol {
            icon: Network.statusIcon
            font.pixelSize: 24
            color: Appearance.fgColor
        }

        MaterialSymbol {
            visible: Bluetooth.enabled
            icon: Bluetooth.statusIcon
            font.pixelSize: 24
            color: Appearance.fgColor
        }

        MaterialSymbol {
            visible: Battery.device.isLaptopBattery
            icon: Battery.iconName
            font.pixelSize: 24
            fill: Battery.percentage
            color: Appearance.fgColor
        }

        BarClock {}
    }
}
