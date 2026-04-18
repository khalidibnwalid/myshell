import QtQuick
import Quickshell
import Quickshell.Services.Notifications
pragma Singleton

Scope {
    id: root

    readonly property alias notifications: notificationModel

    function removeById(id) {
        for (let i = 0; i < notificationModel.count; i++) {
            if (notificationModel.get(i).id === id) {
                notificationModel.remove(i);
                break;
            }
        }
    }

    ListModel {
        id: notificationModel
    }

    NotificationServer {
        onNotification: (notification) => {
            // Add to model
            notificationModel.append({
                "notif": notification,
                "summary": notification.summary,
                "body": notification.body,
                "appName": notification.appName,
                "appIcon": notification.appIcon,
                "id": notification.id
            });
            // Listen for closure from any source (UI, system, timeout)
            notification.closed.connect(() => {
                removeById(notification.id);
            });
        }
    }

}
