import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    title: "System"
    subtitle: SystemInfo.hostname
    Component.onCompleted: {
        SystemInfo.refresh();
        SystemInfo.refreshLive();
    }

    // the page only exists while it is shown, so this stops on its own
    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: SystemInfo.refreshLive()
    }

    SettingGroup {
        title: "Usage"

        SettingCard {
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RingGauge {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: "memory"
                    value: SystemInfo.cpuUsage
                    valueText: Math.round(SystemInfo.cpuUsage * 100) + "%"
                    label: "Processor"
                    detail: SystemInfo.cpuCores > 0 ? SystemInfo.cpuCores + " cores · " + SystemInfo.cpuThreads + " threads" : ""
                }

                RingGauge {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: "memory_alt"
                    value: SystemInfo.memoryPercent
                    valueText: SystemInfo.memoryTotal > 0 ? Math.round(SystemInfo.memoryPercent * 100) + "%" : "—"
                    label: "Memory"
                    detail: SystemInfo.memoryTotal > 0 ? SystemInfo.formatBytes(SystemInfo.memoryUsed) + " of " + SystemInfo.formatBytes(SystemInfo.memoryTotal) : ""
                }

                RingGauge {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: "hard_drive"
                    value: SystemInfo.diskPercent / 100
                    valueText: SystemInfo.diskTotal > 0 ? Math.round(SystemInfo.diskPercent) + "%" : "—"
                    label: "Storage"
                    detail: SystemInfo.diskTotal > 0 ? SystemInfo.formatBytes(SystemInfo.diskAvailable) + " free" : ""
                }

                RingGauge {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: "thermostat"
                    color: SystemInfo.temperature >= 80 ? "#f2b8b5" : Appearance.accentColor
                    value: SystemInfo.temperature >= 0 ? Math.min(1, SystemInfo.temperature / 100) : 0
                    valueText: SystemInfo.temperature >= 0 ? Math.round(SystemInfo.temperature) + "°" : "—"
                    label: "Temperature"
                    detail: SystemInfo.temperature >= 0 ? "Hottest sensor" : "Needs lm_sensors"
                }
            }
        }
    }

    SettingGroup {
        title: "This computer"

        SettingRow {
            icon: "computer"
            title: "Device name"
            description: SystemInfo.hostname || "—"
        }

        SettingRow {
            icon: "deployed_code"
            title: "Operating system"
            description: SystemInfo.osName + (SystemInfo.kernel ? "  ·  Linux " + SystemInfo.kernel : "")
        }

        SettingRow {
            icon: "developer_board"
            title: "Graphics"
            description: SystemInfo.gpuName
        }

        SettingRow {
            icon: "schedule"
            title: "Uptime"
            description: "Time since the computer started"

            StyledText {
                text: SystemInfo.uptimeText
                color: Appearance.mutedColor
            }
        }
    }
}
