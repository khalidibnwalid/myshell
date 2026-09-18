import "../../components/"
import "../../config/"
import "../../services/"
import "./BarClock.qml"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    width: parent.width
    implicitHeight: systemColumn.implicitHeight + 12

    MouseArea {
        anchors.fill: parent
        z: 2
        cursorShape: Qt.PointingHandCursor
        onClicked: WindowManager.setQuickSettingsVisible(!WindowManager.quickSettingsVisible)
    }

    ColumnLayout {
        id: systemColumn

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: 6
        }
        spacing: 6

        MaterialSymbol {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            icon: Network.statusIcon
            font.pixelSize: 21
            color: "#f2f3f1"
        }

        MaterialSymbol {
            visible: Bluetooth.enabled
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            icon: Bluetooth.statusIcon
            font.pixelSize: 21
            color: "#f2f3f1"
        }

        MaterialSymbol {
            visible: Battery.device.isLaptopBattery
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            icon: Battery.iconName
            font.pixelSize: 21
            fill: Battery.percentage
            color: "#f2f3f1"
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: "#f2f3f1"
            font.pixelSize: 11
            font.family: "Monospace"
            font.weight: Font.DemiBold
            text: Keyboard.layout
            opacity: 0.8
        }

        BarClock {
            Layout.fillWidth: true
            fontSize: 14
            spacing: -5
        }
    }
}
