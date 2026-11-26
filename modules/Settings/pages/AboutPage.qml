import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

SettingsPage {
    id: page

    property string runtime: ""
    readonly property string configFile: Quickshell.shellDir + "/config.json"
    readonly property string ipcCommand: "qs ipc call settings toggle"
    property bool copied: false

    title: "About"
    Component.onCompleted: {
        Health.checkTools();
        versionProc.running = true;
    }

    Process {
        id: versionProc

        command: ["qs", "--version"]

        stdout: StdioCollector {
            onStreamFinished: page.runtime = text.trim().split("\n")[0]
        }
    }

    Timer {
        id: copiedTimer

        interval: 1800
        onTriggered: page.copied = false
    }

    SettingGroup {
        title: "Shell"

        SettingRow {
            icon: "widgets"
            title: "Quickshell configuration"
            description: page.runtime || "Quickshell"

            StyledText {
                text: "Version 1.1.0"
                color: Appearance.mutedColor
            }
        }

        SettingRow {
            icon: "description"
            title: "Configuration file"
            description: page.configFile + "  ·  everything in this window is saved here"

            PillButton {
                text: "Open"
                onClicked: Quickshell.execDetached(["xdg-open", page.configFile])
            }

            PillButton {
                text: "Folder"
                onClicked: Quickshell.execDetached(["xdg-open", Quickshell.shellDir])
            }
        }

        SettingRow {
            icon: "keyboard_command_key"
            title: "Open Settings from a key"
            description: page.ipcCommand + "  ·  also: open, close, page <name>"

            PillButton {
                icon: page.copied ? "check" : "content_copy"
                text: page.copied ? "Copied" : "Copy"
                onClicked: {
                    Quickshell.execDetached(["wl-copy", page.ipcCommand]);
                    page.copied = true;
                    copiedTimer.restart();
                }
            }
        }

        SettingRow {
            icon: "refresh"
            title: "Reload the shell"
            description: "Restart the bar, panels and this window"

            PillButton {
                text: "Reload"
                onClicked: Quickshell.reload(true)
            }
        }
    }

    SettingGroup {
        title: "Tools"

        actions: [
            IconButton {
                size: 28
                iconSize: 16
                icon: "refresh"
                onClicked: Health.checkTools()
            }
        ]

        SettingRow {
            visible: Health.toolsChecked && Health.missingTools.length === 0
            icon: "check_circle"
            title: "Everything is installed"
            description: Object.keys(Health.tools).length + " command-line tools the shell relies on were found"
        }

        Repeater {
            model: Health.missingTools

            delegate: SettingRow {
                required property string modelData

                icon: "error"
                title: modelData.split("|").join(" or ") + (modelData.indexOf("|") >= 0 ? " is not installed (either one will do)" : " is not installed")
                description: "Needed for " + Health.tools[modelData]
            }
        }
    }
}
