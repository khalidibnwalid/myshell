import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell

SettingsPage {
    title: "Notifications"
    subtitle: NotificationService.dnd ? "Do not disturb is on" : ""

    SettingGroup {
        SettingRow {
            icon: "do_not_disturb_on"
            title: "Do not disturb"
            description: "Notifications skip the pop-up and wait in the panel"

            ToggleSwitch {
                checked: NotificationService.dnd
                onToggled: on => NotificationService.dnd = on
            }
        }

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

    SettingGroup {
        title: "History"

        SettingRow {
            icon: "notifications"
            title: NotificationService.count === 0 ? "No notifications" : NotificationService.count + (NotificationService.count === 1 ? " notification" : " notifications") + " in the panel"
            description: "Notifications stay in the panel until you dismiss them"

            PillButton {
                enabled: NotificationService.count > 0
                text: "Clear all"
                onClicked: NotificationService.clearAll()
            }
        }

        SettingRow {
            icon: "send"
            title: "Test notification"
            description: "Send one to see how it looks"

            PillButton {
                text: "Send"
                onClicked: Quickshell.execDetached(["notify-send", "-a", "Settings", "Test notification", "This is what a notification looks like."])
            }
        }
    }
}
