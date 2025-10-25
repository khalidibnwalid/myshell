import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../../components"
import "../../config"

ColumnLayout {
    anchors {
        right: parent.right
        left: parent.left
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.bgColor
        radius: 16
        border.color: Appearance.borderColor
        border.width: 2
    }
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        spacing: 8

        Repeater {
            model: SystemTray.items
            delegate: Image {
                anchors.horizontalCenter: parent.horizontalCenter

                source: modelData.icon
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignHCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // TODO: implement menu
                        modelData.activate();
                    }
                }
            }
        }
    }
}
