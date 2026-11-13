import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Layouts
import Quickshell

SettingsPage {
    title: "About"

    SettingRow {
        Layout.fillWidth: true
        first: true
        title: "Shell"
        description: "Quickshell configuration"

        StyledText {
            text: "Version 1.0.0"
            color: Appearance.mutedColor
        }
    }

    SettingRow {
        Layout.fillWidth: true
        last: true
        title: "Configuration"
        description: Quickshell.shellDir + "/config.json"
    }
}
