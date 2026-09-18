import QtQuick
import Quickshell.Services.SystemTray

Item {
    id: root

    implicitWidth: 34
    implicitHeight: trayColumn.implicitHeight

    Column {
        id: trayColumn
        spacing: 8

        Repeater {
            model: SystemTray.items

            delegate: Image {
                required property var modelData

                width: 28
                height: 28
                source: modelData.icon
                fillMode: Image.PreserveAspectFit

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.activate()
                }
            }
        }
    }
}
