import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell

SettingsPage {
    id: page

    readonly property var running: StartupApps.apps.filter(a => a.enabled)
    property string newName: ""
    property string newCommand: ""
    property string pickedApp: ""

    // the installed apps, to pick one to start with the session
    readonly property var installed: DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
                "label": e.name,
                "value": e.id,
                "image": iconOf(e.icon),
                "description": e.comment || ""
            })).sort((a, b) => a.label.localeCompare(b.label))

    function iconOf(name) {
        if (!name)
            return "";
        return name.startsWith("/") ? "file://" + name : Quickshell.iconPath(name, true);
    }

    title: "Startup apps"
    subtitle: running.length + (running.length === 1 ? " app starts" : " apps start") + " with your session"
    Component.onCompleted: StartupApps.refresh()

    SettingGroup {
        title: "Start with your session"

        SettingRow {
            icon: "info"
            title: "The standard autostart folders"
            description: "These are .desktop files in ~/.config/autostart and /etc/xdg/autostart, which your session starts (uwsm). Other programs and desktops read the same files."
        }

        Repeater {
            model: StartupApps.apps

            delegate: SettingRow {
                id: appRow

                required property var modelData

                image: page.iconOf(modelData.icon)
                icon: image === "" ? "apps" : ""
                title: modelData.name
                description: modelData.comment !== "" ? modelData.comment : modelData.exec

                IconButton {
                    visible: appRow.modelData.user && !appRow.modelData.override
                    size: 32
                    iconSize: 18
                    icon: "delete"
                    onClicked: StartupApps.remove(appRow.modelData)
                }

                ToggleSwitch {
                    checked: appRow.modelData.enabled
                    onToggled: on => StartupApps.setEnabled(appRow.modelData, on)
                }
            }
        }

        SettingRow {
            visible: StartupApps.loaded && StartupApps.apps.length === 0
            icon: "rocket_launch"
            title: "Nothing in the autostart folders"
            description: "Add an app below, and it starts with your session"
        }
    }

    SettingGroup {
        title: "Add an app"

        SettingRow {
            icon: "apps"
            title: "An installed app"
            description: "Starts every time you log in"

            Dropdown {
                implicitWidth: 240
                popupWidth: 320
                searchable: true
                placeholder: "Choose an app"
                model: page.installed
                value: page.pickedApp
                onSelected: id => {
                    page.pickedApp = id;
                    const e = DesktopEntries.byId(id);
                    if (e) {
                        StartupApps.add(e.name, e.command.join(" "), e.icon);
                        page.pickedApp = "";
                    }
                }
            }
        }

        SettingRow {
            icon: "terminal"
            title: "A command"
            description: "Any program, with its options"

            FieldInput {
                implicitWidth: 120
                placeholder: "Name"
                value: page.newName
                onEdited: text => page.newName = text
            }

            FieldInput {
                implicitWidth: 200
                placeholder: "command --option"
                value: page.newCommand
                onEdited: text => page.newCommand = text
                onAccepted: {
                    StartupApps.add(page.newName, page.newCommand, "");
                    page.newName = "";
                    page.newCommand = "";
                }
            }

            PillButton {
                text: "Add"
                enabled: page.newName.trim() !== "" && page.newCommand.trim() !== ""
                onClicked: {
                    StartupApps.add(page.newName, page.newCommand, "");
                    page.newName = "";
                    page.newCommand = "";
                }
            }
        }
    }

    SettingGroup {
        visible: StartupApps.hyprland.length > 0
        title: "Started by Hyprland"

        SettingRow {
            icon: "window"
            title: "In your Hyprland config"
            description: "Lines starting exec-once. They are only shown here; change them in the files named below."
        }

        Repeater {
            model: StartupApps.hyprland

            delegate: SettingRow {
                required property var modelData

                icon: "terminal"
                title: modelData.command
                description: modelData.file
            }
        }
    }
}
