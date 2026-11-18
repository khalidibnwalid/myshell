import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

SettingsPage {
    id: page

    // command -> what stops working without it
    readonly property var tools: ({
        "nmcli": "Wi-Fi",
        "brightnessctl": "screen brightness",
        "swaybg": "wallpaper",
        "cliphist": "clipboard history",
        "wl-copy": "clipboard and screenshots",
        "wtype": "paste from the clipboard menu",
        "grim": "screenshots",
        "slurp": "area selection",
        "wl-screenrec": "screen recording",
        "hyprpicker": "colour picker",
        "notify-send": "capture notifications",
        "tesseract": "Extract text from a screen area",
        "zbarimg": "reading QR codes in the screenshot selector",
        "udevadm": "camera on and off message",
        "bc": "calculator in the launcher",
        "hyprsunset": "night light",
        "matugen": "colours from the wallpaper",
        "sensors": "temperatures",
        "lspci": "graphics information",
        "gio": "default apps and file previews in the launcher",
        "xdg-mime": "changing default apps",
        "busctl": "results from apps in the launcher",
        "python3": "recent files, VS Code and browser history in the launcher",
        "ffmpegthumbnailer": "album covers and video frames in the launcher",
        "ffprobe": "tags and covers in the Audio player",
        "ffmpeg": "covers in the Audio player",
        "udisksctl": "mounting and ejecting drives",
        "lpstat": "printers",
        "hostnamectl": "changing the computer name",
        "timedatectl": "time zone and clock settings",
        "localectl": "language and formats",
        "gnome-control-center": "adding online accounts"
    })
    property var missing: []
    property bool checked: false
    property string runtime: ""
    readonly property string configFile: Quickshell.shellDir + "/config.json"
    readonly property string ipcCommand: "qs ipc call settings toggle"
    property bool copied: false

    title: "About"
    Component.onCompleted: {
        checkProc.running = true;
        versionProc.running = true;
    }

    Process {
        id: checkProc

        command: ["sh", "-c", "for t; do command -v \"$t\" >/dev/null 2>&1 || echo \"$t\"; done", "sh"].concat(Object.keys(page.tools))

        stdout: StdioCollector {
            onStreamFinished: {
                page.missing = text.split("\n").filter(Boolean);
                page.checked = true;
            }
        }
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
                onClicked: checkProc.running = true
            }
        ]

        SettingRow {
            visible: page.checked && page.missing.length === 0
            icon: "check_circle"
            title: "Everything is installed"
            description: Object.keys(page.tools).length + " command-line tools the shell relies on were found"
        }

        Repeater {
            model: page.missing

            delegate: SettingRow {
                required property string modelData

                icon: "error"
                title: modelData + " is not installed"
                description: "Needed for " + page.tools[modelData]
            }
        }
    }
}
