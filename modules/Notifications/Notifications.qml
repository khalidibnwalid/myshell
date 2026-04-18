import "../../config"
import "../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Scope {
    id: root

    PanelWindow {
        id: notificationWindow

        anchors.top: true
        anchors.right: true
        margins.top: 10
        margins.right: Config.layout.barPosition === "right" ? 60 : 10
        margins.left: Config.layout.barPosition === "left" ? 60 : 10
        // We want the window to be as large as the content
        // but not block everything if empty
        implicitWidth: 370
        implicitHeight: Math.min(600, layout.implicitHeight)
        color: "transparent"
        visible: Notifications.model.count > 0

        ColumnLayout {
            id: layout

            anchors.fill: parent
            spacing: 8

            ListView {
                id: notificationList

                Layout.fillWidth: true
                Layout.fillHeight: true
                model: Notifications.model
                spacing: 8
                interactive: false // Let them stack and scroll naturally if needed, but usually just a few

                delegate: NotificationItem {
                    notification: model.notification
                    summary: model.summary
                    body: model.body
                    appName: model.appName
                    appIcon: model.appIcon
                    anchors.right: parent.right
                }

                // Add a nice move animation for items shifting up when one is removed
                move: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        // Use a click mask to allow clicking through the empty space of the window
        mask: Region {
            rects: [Qt.rect(0, 0, notificationWindow.width, notificationWindow.height)]
        }

    }

}
