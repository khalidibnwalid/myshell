import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    title: "General"

    SettingRow {
        Layout.fillWidth: true
        first: true
        title: "Keyboard layout"
        description: "Current input language"

        StyledText {
            text: Keyboard.fullLayoutName || Keyboard.layout
            color: Appearance.mutedColor
        }
    }

    SettingRow {
        Layout.fillWidth: true
        title: "Dock"
        description: "Bottom dock on empty workspaces and at the bottom edge of the screen"

        PillButton {
            text: Config.dock.enabled ? "On" : "Off"
            toggled: Config.dock.enabled
            onClicked: Config.dock.enabled = !Config.dock.enabled
        }
    }

    SettingRow {
        Layout.fillWidth: true
        title: "Save screenshots"
        description: "Also keep a file in " + Config.capture.screenshotDir + "; screenshots are always copied"

        PillButton {
            text: Config.capture.autoSave ? "On" : "Off"
            toggled: Config.capture.autoSave
            onClicked: Config.capture.autoSave = !Config.capture.autoSave
        }
    }

    SettingRow {
        Layout.fillWidth: true
        title: "Lock on idle"
        description: "Secure the session with the matching Quickshell lock screen"

        PillButton {
            text: Config.idle.enabled ? "On" : "Off"
            toggled: Config.idle.enabled
            onClicked: Config.idle.enabled = !Config.idle.enabled
        }
    }

    SettingRow {
        Layout.fillWidth: true
        title: "Lock after"
        description: "Time without input before the session locks"

        PillButton {
            readonly property var options: [1, 3, 5, 10, 15, 30]
            text: Config.idle.lockAfterMinutes + " min"
            onClicked: {
                const index = options.indexOf(Config.idle.lockAfterMinutes);
                Config.idle.lockAfterMinutes = options[(index + 1) % options.length];
            }
        }
    }

    SettingRow {
        Layout.fillWidth: true
        title: "Turn displays off"
        description: "After locking; choose Off to keep them on"

        PillButton {
            readonly property var options: [0, 10, 15, 30, 60]
            text: Config.idle.screenOffAfterMinutes === 0 ? "Off" : Config.idle.screenOffAfterMinutes + " min"
            toggled: Config.idle.screenOffAfterMinutes > 0
            onClicked: {
                const index = options.indexOf(Config.idle.screenOffAfterMinutes);
                Config.idle.screenOffAfterMinutes = options[(index + 1) % options.length];
            }
        }
    }

    SettingRow {
        Layout.fillWidth: true
        last: true
        title: "Do not disturb"
        description: "Notifications arrive silently in the panel"

        PillButton {
            text: NotificationService.dnd ? "On" : "Off"
            toggled: NotificationService.dnd
            onClicked: NotificationService.dnd = !NotificationService.dnd
        }
    }
}
