import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell

SettingsPage {
    id: page

    function iconOf(desktopId) {
        const e = DefaultApps.entryOf(desktopId);
        const name = e ? e.icon : "";
        if (!name)
            return "";
        return name.startsWith("/") ? "file://" + name : Quickshell.iconPath(name, true);
    }

    function choices(id) {
        return DefaultApps.appsOf(id).map(d => {
            const e = DefaultApps.entryOf(d);
            return {
                "label": e ? e.name : d.replace(/\.desktop$/, ""),
                "value": d,
                "image": page.iconOf(d),
                "description": e ? (e.comment || "") : ""
            };
        });
    }

    title: "Default apps"
    subtitle: "Which app opens links, folders, images and more"
    Component.onCompleted: DefaultApps.refresh()

    SettingGroup {
        title: "Open with"

        SettingRow {
            icon: "info"
            title: "The system's own choice"
            description: "Saved in ~/.config/mimeapps.list through xdg-mime, so every program agrees. Each choice applies to all the types listed under it."
        }

        Repeater {
            model: DefaultApps.categories

            delegate: SettingRow {
                id: catRow

                required property var modelData
                readonly property string current: DefaultApps.currentOf(modelData.id)

                icon: modelData.icon
                title: modelData.title
                description: modelData.description

                Dropdown {
                    implicitWidth: 240
                    popupWidth: 320
                    searchable: true
                    placeholder: DefaultApps.loaded ? "Not set" : "Reading…"
                    model: page.choices(catRow.modelData.id)
                    value: catRow.current
                    onSelected: d => DefaultApps.set(catRow.modelData.id, d)
                }
            }
        }
    }
}
