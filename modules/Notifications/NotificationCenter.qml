import "../../components"
import "../../config"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

Scope {
    id: root

    function removeById(id) {
        for (let i = 0; i < notificationModel.count; i++) {
            if (notificationModel.get(i).notifId === id) {
                console.log("Center: Removing ID", id);
                notificationModel.remove(i);
                break;
            }
        }
    }

    // Central model
    ListModel {
        id: notificationModel
    }

    // Central server
    NotificationServer {
        onNotification: (notification) => {
            console.log("Center: Adding", notification.summary);
            notificationModel.append({
                "notif": notification,
                "summary": notification.summary,
                "body": notification.body,
                "appName": notification.appName,
                "appIcon": notification.appIcon,
                "notifId": notification.id
            });
            notification.closed.connect(() => {
                removeById(notification.id);
            });
        }
    }

    PanelWindow {
        id: notificationWindow

        anchors.top: true
        anchors.right: true
        margins.top: 10
        margins.right: Config.layout.barPosition === "right" ? 60 : 10
        margins.left: Config.layout.barPosition === "left" ? 60 : 10
        implicitWidth: 370
        implicitHeight: Math.min(600, Math.max(1, notificationList.contentHeight))
        color: "transparent"
        visible: notificationModel.count > 0

        ListView {
            id: notificationList

            anchors.fill: parent
            model: notificationModel
            spacing: 8
            interactive: false

            delegate: NotificationItem {
                notification: model.notif
                summary: model.summary
                body: model.body
                appName: model.appName
                appIcon: model.appIcon
                width: notificationList.width
                // Allow the item to tell us to remove it
                onDismissed: root.removeById(model.notifId)
            }

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

}
