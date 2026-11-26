import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

// Quick Settings page: the connected Wi-Fi as a QR code (see components/WifiShare.qml)
Item {
    id: root

    property var stackView

    implicitHeight: layout.implicitHeight + 32

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 14

        PageHeader {
            Layout.fillWidth: true
            title: "Share Wi-Fi"
            subtitle: share.ssid !== "" ? share.ssid : (Network.active?.ssid ?? "")
            onBack: root.stackView.pop()
        }

        WifiShare {
            id: share

            Layout.fillWidth: true
        }
    }
}
