import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

// Drives and partitions: mount, unmount, eject. There is no formatting here.
SettingsPage {
    id: page

    function gb(bytes) {
        return SystemInfo.formatBytes(bytes);
    }

    function healthText(h) {
        return h === "good" ? "Healthy" : (h === "bad" ? "Failing: back it up" : "Health needs administrator rights to read");
    }

    title: "Storage"
    subtitle: Storage.drives.length + (Storage.drives.length === 1 ? " drive" : " drives")
    Component.onCompleted: {
        Storage.refresh();
        SystemInfo.refresh();
    }

    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: Storage.refresh()
    }

    Repeater {
        model: Storage.drives

        delegate: SettingGroup {
            id: drive

            required property var modelData

            title: modelData.kind + (modelData.model !== "" ? " · " + modelData.model : "") + " · /dev/" + modelData.name

            SettingRow {
                icon: drive.modelData.removable ? "usb" : "hard_drive"
                title: drive.modelData.model !== "" ? drive.modelData.model : drive.modelData.name
                description: page.gb(drive.modelData.size) + "  ·  " + page.healthText(drive.modelData.health)

                PillButton {
                    visible: drive.modelData.removable
                    icon: "eject"
                    text: "Eject"
                    enabled: Storage.busy === ""
                    onClicked: Storage.eject(drive.modelData)
                }
            }

            Repeater {
                model: drive.modelData.parts

                delegate: SettingCard {
                    id: part

                    required property var modelData
                    readonly property bool mounted: modelData.mounts.length > 0
                    readonly property bool canToggle: modelData.fstype !== "" && modelData.fstype !== "swap" && modelData.fstype !== "crypto_LUKS" && !modelData.system

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        MaterialSymbol {
                            icon: part.mounted ? "folder_open" : "folder"
                            font.pixelSize: 20
                            color: Appearance.mutedColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: part.modelData.label !== "" ? part.modelData.label : "/dev/" + part.modelData.name
                                elide: Text.ElideRight
                                font.weight: Font.Medium
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: [part.modelData.fstype || "no file system", page.gb(part.modelData.size), part.mounted ? "Mounted at " + part.modelData.mounts.join(", ") : "Not mounted"].join("  ·  ")
                                elide: Text.ElideRight
                                color: Appearance.mutedColor
                                font.pixelSize: 12
                            }
                        }

                        PillButton {
                            visible: part.mounted && part.modelData.mounts[0].indexOf("[") < 0
                            icon: "folder_open"
                            text: "Open"
                            onClicked: Storage.openFolder(part.modelData.mounts[0])
                        }

                        PillButton {
                            visible: part.canToggle
                            enabled: Storage.busy === ""
                            text: Storage.busy === part.modelData.path ? "Working…" : (part.mounted ? "Unmount" : "Mount")
                            onClicked: part.mounted ? Storage.unmount(part.modelData.path) : Storage.mount(part.modelData.path)
                        }
                    }

                    Meter {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        visible: part.modelData.used >= 0 && part.modelData.size > 0
                        value: part.modelData.size > 0 ? Math.max(0, part.modelData.used) / part.modelData.size : 0
                        fillColor: part.modelData.size > 0 && part.modelData.used / part.modelData.size >= 0.9 ? "#f2b8b5" : Appearance.accentColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: part.modelData.used >= 0 && part.modelData.size > 0
                        text: page.gb(part.modelData.used) + " used of " + page.gb(part.modelData.size)
                        color: Appearance.mutedColor
                        font.pixelSize: 11
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: part.modelData.system && part.mounted
                        text: "Used by the system, so it can't be unmounted here"
                        color: Appearance.mutedColor
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    SettingGroup {
        visible: Storage.loaded && Storage.drives.length === 0

        SettingRow {
            icon: "hard_drive"
            title: "No drives found"
        }
    }
}
