import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

SettingsPage {
    id: page

    // installed apps that are not in the dock yet, by name
    readonly property var addable: DesktopEntries.applications.values.filter(e => !DockApps.isPinned(e.id)).map(e => ({
        "label": e.name,
        "value": e.id
    })).sort((a, b) => a.label.localeCompare(b.label))

    title: "Bar & dock"

    SettingGroup {
        title: "Bar"

        SettingRow {
            icon: "dock_to_right"
            title: "Position"
            description: "Which edge of the screen the bar sits on; panels and pop-ups follow it"

            Segmented {
                model: ["left", "right", "top", "bottom"].map(side => ({
                    "label": side.charAt(0).toUpperCase() + side.slice(1),
                    "value": side
                }))
                value: Config.barPosition
                onSelected: side => Config.layout.barPosition = side
            }
        }

        SettingRow {
            icon: "schedule"
            title: "24-hour clock"
            description: "In the bar, quick settings and on the lock screen · now " + Time.format(Config.bar.clock24h ? "HH:mm" : "hh:mm AP")

            ToggleSwitch {
                checked: Config.bar.clock24h
                onToggled: on => Config.bar.clock24h = on
            }
        }
    }

    SettingGroup {
        title: "Tray"

        SettingRow {
            icon: "apps"
            title: "Icons shown"
            description: "How many tray icons stay in the bar; the rest fold behind the arrow"

            StyledText {
                Layout.preferredWidth: 24
                horizontalAlignment: Text.AlignRight
                text: Config.bar.trayVisible
                font.weight: Font.Medium
            }

            IconButton {
                enabled: Config.bar.trayVisible > 1
                opacity: enabled ? 1 : 0.3
                icon: "remove"
                onClicked: Config.bar.trayVisible = Config.bar.trayVisible - 1
            }

            IconButton {
                enabled: Config.bar.trayVisible < 12
                opacity: enabled ? 1 : 0.3
                icon: "add"
                onClicked: Config.bar.trayVisible = Config.bar.trayVisible + 1
            }
        }

        Repeater {
            model: SystemTray.items

            delegate: SettingRow {
                id: trayRow

                required property var modelData

                image: modelData.icon
                title: modelData.title || modelData.id
                description: "Show this app in the bar"

                ToggleSwitch {
                    checked: Config.trayHiddenList.indexOf(trayRow.modelData.id) < 0
                    onToggled: on => Config.setTrayHidden(trayRow.modelData.id, !on)
                }
            }
        }

        SettingRow {
            visible: SystemTray.items.values.length === 0
            title: "No tray apps running"
            description: "Apps with a tray icon show up here, so you can hide the ones you do not want"
        }
    }

    SettingGroup {
        title: "Dock"

        SettingRow {
            icon: "dock_to_bottom"
            title: "Show the dock"
            description: "On empty workspaces and when the pointer reaches the bottom edge"

            ToggleSwitch {
                checked: Config.dock.enabled
                onToggled: on => Config.dock.enabled = on
            }
        }
    }

    SettingGroup {
        title: "Pinned apps"

        actions: [
            Dropdown {
                model: page.addable
                caption: "Add app"
                icon: "add"
                searchable: true
                popupWidth: 300
                onSelected: id => DockApps.pin(id)
            }
        ]

        Repeater {
            model: DockApps.pins

            delegate: SettingRow {
                id: pinned

                required property string modelData
                required property int index
                readonly property var entry: DesktopEntries.byId(modelData)

                image: DockApps.iconFor(entry, modelData)
                title: entry?.name || modelData
                description: entry?.comment || (entry ? "" : "Not installed")

                IconButton {
                    enabled: pinned.index > 0
                    opacity: enabled ? 1 : 0.3
                    icon: "arrow_upward"
                    onClicked: DockApps.pin(pinned.modelData, pinned.index - 1)
                }

                IconButton {
                    enabled: pinned.index < DockApps.pins.length - 1
                    opacity: enabled ? 1 : 0.3
                    icon: "arrow_downward"
                    onClicked: DockApps.pin(pinned.modelData, pinned.index + 1)
                }

                IconButton {
                    icon: "close"
                    onClicked: DockApps.unpin(pinned.modelData)
                }
            }
        }

        SettingRow {
            visible: DockApps.pins.length === 0
            title: "No pinned apps"
            description: "Use “Add app” to pin one; running apps always show in the dock"
        }
    }
}
