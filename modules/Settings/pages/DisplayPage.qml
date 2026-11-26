import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

SettingsPage {
    id: page

    title: "Display"
    Component.onCompleted: {
        NightLight.refresh();
        Hyprland.refreshMonitors();
    }
    // an unconfirmed change does not outlive the page
    Component.onDestruction: Displays.revert()

    // the display whose settings are shown below
    property string selectedName: ""
    readonly property var monitorList: Hyprland.monitors.values
    readonly property string activeName: monitorList.some(m => m.name === selectedName) ? selectedName : (monitorList[0]?.name ?? "")

    Backlight {
        id: backlight
    }

    SettingGroup {
        visible: page.monitorList.length > 0
        title: "Arrange"

        SettingCard {
            DisplayMap {
                Layout.fillWidth: true
                monitors: page.monitorList
                selected: page.activeName
                onPicked: name => page.selectedName = name
            }

            StyledText {
                Layout.fillWidth: true
                text: page.monitorList.length > 1 ? "Select a display to change its settings. Drag displays to rearrange them." : "Select a display to change its settings."
                color: Appearance.mutedColor
                font.pixelSize: 12
            }
        }
    }

    SettingGroup {
        visible: Displays.pending !== null
        title: "Confirm"

        SettingRow {
            icon: "help"
            title: "Keep these display settings?"
            description: "Going back to the previous settings in " + Displays.secondsLeft + " s"

            PillButton {
                text: "Revert"
                onClicked: Displays.revert()
            }

            PillButton {
                toggled: true
                text: "Keep"
                onClicked: Displays.keep()
            }
        }
    }

    Repeater {
        model: Hyprland.monitors

        delegate: SettingGroup {
            id: monitorGroup

            visible: modelData.name === page.activeName

            required property var modelData
            readonly property string mode: Displays.currentMode(modelData)

            title: (page.monitorList.indexOf(modelData) + 1) + "  ·  " + modelData.name + (modelData.description ? "  ·  " + modelData.description : "")

            SettingRow {
                icon: "aspect_ratio"
                title: "Resolution and refresh rate"
                description: Math.round(monitorGroup.modelData.width / monitorGroup.modelData.scale) + " × " + Math.round(monitorGroup.modelData.height / monitorGroup.modelData.scale) + " after scaling"

                Dropdown {
                    model: Displays.modes(monitorGroup.modelData).map(m => ({
                        "label": Displays.modeLabel(m),
                        "value": m
                    }))
                    value: monitorGroup.mode
                    placeholder: Displays.modeLabel(monitorGroup.mode)
                    popupWidth: 240
                    onSelected: m => {
                        if (m !== monitorGroup.mode)
                            Displays.change(monitorGroup.modelData, m, monitorGroup.modelData.scale);
                    }
                }
            }

            SettingRow {
                icon: "zoom_in"
                title: "Scale"
                description: "How large text and windows appear"

                Dropdown {
                    model: Displays.scales(monitorGroup.mode, monitorGroup.modelData.scale).map(s => ({
                        "label": Math.round(s * 100) + "%",
                        "value": s
                    }))
                    value: monitorGroup.modelData.scale
                    placeholder: Math.round(monitorGroup.modelData.scale * 100) + "%"
                    popupWidth: 140
                    onSelected: s => {
                        if (s !== monitorGroup.modelData.scale)
                            Displays.change(monitorGroup.modelData, monitorGroup.mode, s);
                    }
                }
            }

            SettingRow {
                visible: Displays.isSaved(monitorGroup.modelData.name)
                icon: "restart_alt"
                title: "Set from Settings"
                description: "Applied every time the shell starts. Reset to use the Hyprland config again."

                PillButton {
                    text: "Reset"
                    onClicked: Displays.forget(monitorGroup.modelData.name)
                }
            }
        }
    }

    SettingGroup {
        visible: page.monitorList.length > 1 || HyprSettings.workspaceSplit
        title: "Workspaces"

        SettingRow {
            icon: "grid_view"
            title: "Separate workspaces per screen"
            description: HyprSettings.workspaceSplit ? "Screen " + HyprSettings.workspaceScreens.map((n, k) => n + " has " + (k * HyprSettings.workspaceCount + 1) + "–" + ((k + 1) * HyprSettings.workspaceCount)).join(", ") + ". An unplugged screen's workspaces show on the other one." + (HyprSettings.workspaceScreens.length > 1 ? " Super + ` then 1–" + HyprSettings.workspaceCount + " jumps to that workspace of the second screen." : "") : "Each screen keeps its own numbers, so switching on one never pulls workspaces off another."

            ToggleSwitch {
                enabled: HyprSettings.enabled
                checked: HyprSettings.workspaceSplit
                onToggled: on => HyprSettings.setWorkspaceSplit(on)
            }
        }

        SettingRow {
            visible: HyprSettings.workspaceSplit
            icon: "pin"
            title: "Workspaces per screen"
            description: "How many numbers each screen gets"

            NumberStepper {
                from: 1
                to: 10
                value: HyprSettings.workspaceCount
                onChanged: v => HyprSettings.setWorkspaceCount(v)
            }
        }

        SettingRow {
            visible: HyprSettings.workspaceSplit
            icon: "view_sidebar"
            title: "Bar shows only its own screen's workspaces"
            description: "Each bar lists its screen's set, marks the active one, and adds any workspace past the set (11, 12 …) on the screen that holds it. Off lists every workspace on every bar."

            ToggleSwitch {
                checked: HyprSettings.barOwnWorkspaces
                onToggled: on => HyprSettings.setBarOwnWorkspaces(on)
            }
        }

        SettingRow {
            visible: HyprSettings.workspaceSplit
            icon: "keyboard"
            title: "Super+Shift+number switches every screen"
            description: "Super+Shift+2 shows workspace 2 of each screen at once. Moving a window without following it goes to Super+Alt+number."

            ToggleSwitch {
                checked: HyprSettings.pairKeys
                onToggled: on => HyprSettings.setPairKeys(on)
            }
        }
    }

    SettingGroup {
        title: "Brightness"

        SettingRow {
            icon: "light_mode"
            title: "Screen brightness"
            description: "Backlight level"

            StyledText {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round(backlight.percentage * 100) + "%"
                font.weight: Font.Medium
            }

            PillSlider {
                implicitWidth: 280
                implicitHeight: 36
                icon: "light_mode"
                value: backlight.percentage
                // never all the way to black
                onDragged: v => backlight.setBrightness(Math.max(0.02, v))
            }
        }

        // a dim laid over one screen, for displays without a backlight of their own
        Repeater {
            model: page.monitorList

            delegate: SettingRow {
                id: dimRow

                required property var modelData

                icon: "brightness_6"
                title: "Dim " + modelData.name
                description: "Darkens just this screen. Works on any display, on top of its backlight."

                StyledText {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: ScreenDim.levelOf(dimRow.modelData.name) + "%"
                    font.weight: Font.Medium
                }

                PillSlider {
                    implicitWidth: 280
                    implicitHeight: 36
                    icon: "brightness_6"
                    // the slider runs over the allowed range
                    value: (ScreenDim.levelOf(dimRow.modelData.name) - ScreenDim.minLevel) / (100 - ScreenDim.minLevel)
                    onDragged: v => ScreenDim.setLevel(dimRow.modelData.name, ScreenDim.minLevel + v * (100 - ScreenDim.minLevel))
                }
            }
        }
    }

    SettingGroup {
        visible: NightLight.available
        title: "Night light"

        actions: [
            PillButton {
                visible: NightLight.available && !NightLight.isDefault
                implicitHeight: 28
                icon: "restart_alt"
                text: "Reset to " + NightLight.defaultTemperature + " K · " + NightLight.defaultGamma + "%"
                onClicked: NightLight.reset()
            }
        ]

        SettingRow {
            icon: "nightlight"
            title: "Screen filter"
            description: NightLight.available ? (NightLight.active ? "On · " + NightLight.temperature + " K at " + NightLight.gamma + "% brightness" : "Off · colours and brightness untouched") : "Needs hyprsunset running in the background"

            ToggleSwitch {
                enabled: NightLight.available
                checked: NightLight.active
                onToggled: on => NightLight.setActive(on)
            }
        }

        SettingRow {
            visible: NightLight.available
            icon: "thermostat"
            title: "Colour temperature"
            description: "Lower is warmer and easier on the eyes at night"

            StyledText {
                Layout.preferredWidth: 56
                horizontalAlignment: Text.AlignRight
                text: NightLight.temperature + " K"
                font.weight: Font.Medium
            }

            PillSlider {
                readonly property int span: NightLight.maxTemperature - NightLight.minTemperature

                implicitWidth: 280
                implicitHeight: 36
                icon: "thermostat"
                value: (NightLight.temperature - NightLight.minTemperature) / span
                onDragged: v => NightLight.setTemperature(NightLight.minTemperature + v * span)
            }
        }

        SettingRow {
            visible: NightLight.available
            icon: "brightness_medium"
            title: "Filter brightness"
            description: "Dims the picture itself, on top of the backlight"

            StyledText {
                Layout.preferredWidth: 56
                horizontalAlignment: Text.AlignRight
                text: NightLight.gamma + "%"
                font.weight: Font.Medium
            }

            PillSlider {
                readonly property int span: NightLight.maxGamma - NightLight.minGamma

                implicitWidth: 280
                implicitHeight: 36
                icon: "brightness_medium"
                value: (NightLight.gamma - NightLight.minGamma) / span
                onDragged: v => NightLight.setGamma(NightLight.minGamma + v * span)
            }
        }
    }
}
