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
