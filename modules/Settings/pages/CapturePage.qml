import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell

SettingsPage {
    id: page

    property bool confirmClear: false

    function openFolder(path) {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "sh", ScreenTools.expand(path)]);
    }

    title: "Clipboard & capture"
    Component.onCompleted: Clipboard.refresh()

    Timer {
        id: confirmTimer

        interval: 4000
        onTriggered: page.confirmClear = false
    }

    SettingGroup {
        title: "Clipboard"

        SettingRow {
            icon: "content_paste_go"
            title: "Paste when picked"
            description: "Picking an item in the clipboard menu pastes it into the focused window; off only copies it"

            ToggleSwitch {
                checked: Config.clipboard?.autoPaste ?? true
                onToggled: on => Config.setIn("clipboard", "autoPaste", on)
            }
        }

        SettingRow {
            icon: "history"
            title: "History"
            description: Clipboard.history.length + " items  ·  " + Clipboard.pins.length + " pinned" + (page.confirmClear ? "  ·  click again to clear; pinned items stay" : "")

            PillButton {
                enabled: Clipboard.history.length > 0
                toggled: page.confirmClear
                text: page.confirmClear ? "Confirm" : "Clear history"
                onClicked: {
                    if (!page.confirmClear) {
                        page.confirmClear = true;
                        confirmTimer.restart();
                        return;
                    }
                    page.confirmClear = false;
                    Clipboard.wipe();
                }
            }
        }
    }

    SettingGroup {
        title: "Screenshots"

        SettingRow {
            icon: "save"
            title: "Save every screenshot"
            description: "Screenshots are always copied; this also keeps a file. When off, click the notification to save one."

            ToggleSwitch {
                checked: Config.capture.autoSave
                onToggled: on => Config.capture.autoSave = on
            }
        }

        SettingRow {
            icon: "draw"
            title: "Open the editor after a screenshot"
            description: Config.capture.openEditor ? "Each screenshot opens in the editor, where you can draw on it, hide parts and crop it before you copy or save it." : "A notification comes instead; its Edit button opens the editor."

            ToggleSwitch {
                checked: Config.capture.openEditor
                onToggled: on => Config.capture.openEditor = on
            }
        }

        SettingRow {
            icon: "document_scanner"
            title: "Text languages"
            description: "Languages read by Extract text, joined with + (for example eng+ara). Installed: eng. More come from tesseract-data packages."

            FieldInput {
                implicitWidth: 240
                value: Config.capture.ocrLanguages
                onCommitted: text => {
                    if (/^[a-z_]+(\+[a-z_]+)*$/.test(text.trim()))
                        Config.capture.ocrLanguages = text.trim();
                }
            }
        }

        SettingRow {
            icon: "folder"
            title: "Screenshot folder"
            description: "Where saved screenshots go"

            FieldInput {
                implicitWidth: 240
                value: Config.capture.screenshotDir
                onCommitted: text => {
                    if (text.trim() !== "")
                        Config.capture.screenshotDir = text.trim();
                }
            }

            IconButton {
                icon: "folder_open"
                onClicked: page.openFolder(Config.capture.screenshotDir)
            }
        }

        SettingRow {
            icon: "screenshot_region"
            title: "Take a screenshot"
            description: "Select an area of the screen"

            PillButton {
                text: "Capture"
                onClicked: ScreenTools.screenshot()
            }
        }
    }

    SettingGroup {
        title: "Screen recording"

        SettingRow {
            icon: "mic"
            title: "Record audio"
            description: "Include sound in screen recordings"

            ToggleSwitch {
                checked: Config.capture.recordAudio
                onToggled: on => Config.capture.recordAudio = on
            }
        }

        SettingRow {
            icon: "folder"
            title: "Recording folder"
            description: "Where recordings are saved"

            FieldInput {
                implicitWidth: 240
                value: Config.capture.recordingDir
                onCommitted: text => {
                    if (text.trim() !== "")
                        Config.capture.recordingDir = text.trim();
                }
            }

            IconButton {
                icon: "folder_open"
                onClicked: page.openFolder(Config.capture.recordingDir)
            }
        }

        SettingRow {
            icon: "videocam"
            title: ScreenTools.recording ? "Recording · " + ScreenTools.elapsedText : "Record the screen"
            description: ScreenTools.recording ? "Stop to save the file" : "Select an area to record"

            PillButton {
                toggled: ScreenTools.recording
                text: ScreenTools.recording ? "Stop" : "Record"
                onClicked: ScreenTools.toggleRecording()
            }
        }
    }
}
