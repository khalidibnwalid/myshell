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
