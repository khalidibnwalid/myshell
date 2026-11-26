import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell

// What is wrong with the shell, grouped by kind, with a fix where a safe one exists (see services/Health.qml).
// The checks run when the page opens and on Refresh, never in the background.
SettingsPage {
    id: page

    // key of the problem whose text was just copied
    property string copied: ""

    function copy(key, text) {
        Quickshell.execDetached(["wl-copy", "--", text]);
        copied = key;
        copiedTimer.restart();
    }

    title: "Health"
    subtitle: "What is wrong with the shell, and a fix where there is a safe one"
    Component.onCompleted: Health.refresh()
    headerActions: [
        PillButton {
            icon: "refresh"
            text: Health.checking ? "Checking…" : "Refresh"
            enabled: !Health.checking
            onClicked: Health.refresh()
        }
    ]

    Timer {
        id: copiedTimer

        interval: 1800
        onTriggered: page.copied = ""
    }

    SettingGroup {
        SettingRow {
            icon: !Health.loaded ? "hourglass_empty" : Health.problemCount === 0 ? "check_circle" : "health_and_safety"
            title: !Health.loaded ? "Checking…" : Health.problemCount === 0 ? "All good" : Health.problemCount === 1 ? "1 thing needs a look" : Health.problemCount + " things need a look"
            description: Health.loaded && Health.problemCount === 0 ? "Tools, helpers, the shell log, Hyprland, the apps' desktop entries and services were checked" : ""
        }
    }

    Repeater {
        model: Health.loaded ? Health.groups : []

        delegate: SettingGroup {
            id: group

            required property var modelData

            title: modelData.title

            Repeater {
                model: group.modelData.items

                delegate: SettingRow {
                    id: row

                    required property var modelData

                    icon: modelData.icon
                    title: modelData.title
                    description: modelData.description || ""

                    PillButton {
                        visible: !!row.modelData.copy
                        icon: page.copied === row.modelData.key ? "check" : "content_copy"
                        text: page.copied === row.modelData.key ? "Copied" : "Copy"
                        onClicked: page.copy(row.modelData.key, row.modelData.copy)
                    }

                    PillButton {
                        visible: !!row.modelData.fix
                        toggled: true
                        enabled: Health.busy === ""
                        text: Health.busy !== "" && Health.busy === row.modelData.action ? (row.modelData.action.startsWith("build:") ? "Building…" : "Working…") : (row.modelData.fix || "")
                        onClicked: Health.fix(row.modelData.action)
                    }
                }
            }

            // the lines themselves (log errors, Hyprland config errors)
            Repeater {
                model: group.modelData.items.filter(i => i.lines && i.lines.length > 0)

                delegate: SettingCard {
                    id: card

                    required property var modelData

                    Repeater {
                        model: card.modelData.lines

                        delegate: StyledText {
                            required property string modelData

                            Layout.fillWidth: true
                            text: modelData
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.family: "monospace"
                            font.pixelSize: 12
                            color: Appearance.mutedColor
                        }
                    }
                }
            }
        }
    }
}
