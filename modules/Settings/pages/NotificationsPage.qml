import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell

SettingsPage {
    title: "Notifications"
    subtitle: NotificationService.dnd ? "Do not disturb is on" : ""

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        BigTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            icon: NotificationService.dnd ? "do_not_disturb_on" : "notifications_active"
            title: "Do not disturb"
            subtitle: NotificationService.dnd ? "On · pop-ups are held back" : "Off · pop-ups are shown"
            toggled: NotificationService.dnd
            onClicked: NotificationService.dnd = !NotificationService.dnd
        }

        BigTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            icon: "delete_sweep"
            title: "Clear all"
            subtitle: NotificationService.count === 0 ? "Nothing in the panel" : NotificationService.count + " in the panel"
            enabled: NotificationService.count > 0
            opacity: enabled ? 1 : 0.5
            onClicked: NotificationService.clearAll()
        }

        BigTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            icon: "send"
            title: "Test"
            subtitle: "Send a sample pop-up"
            onClicked: Quickshell.execDetached(["notify-send", "-a", "Settings", "Test notification", "This is what a notification looks like."])
        }
    }

    SettingGroup {
        SettingRow {
            icon: "timer"
            title: "Pop-up duration"
            description: "How long a notification stays on screen when the app does not choose"

            Segmented {
                model: [3, 5, 8, 12, 20].map(s => ({
                    "label": s + " s",
                    "value": s
                }))
                value: Config.notifications.popupSeconds
                onSelected: s => Config.notifications.popupSeconds = s
            }
        }
    }
}
