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

        SettingRow {
            icon: "memory"
            title: "Processor"
            description: SystemInfo.cpuModel + (SystemInfo.cpuCores > 0 ? "  ·  " + SystemInfo.cpuCores + " cores, " + SystemInfo.cpuThreads + " threads" : "")

            Meter {
                value: SystemInfo.cpuUsage
            }

            StyledText {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round(SystemInfo.cpuUsage * 100) + "%"
                color: Appearance.mutedColor
            }
        }

        SettingRow {
            icon: "memory_alt"
            title: "Memory"
            description: SystemInfo.memoryTotal > 0 ? SystemInfo.formatBytes(SystemInfo.memoryUsed) + " used of " + SystemInfo.formatBytes(SystemInfo.memoryTotal) : "Unavailable"

            Meter {
                value: SystemInfo.memoryPercent
            }

            StyledText {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: SystemInfo.memoryTotal > 0 ? Math.round(SystemInfo.memoryPercent * 100) + "%" : "—"
                color: Appearance.mutedColor
            }
        }

        SettingRow {
            icon: "hard_drive"
            title: "Storage"
            description: SystemInfo.diskTotal > 0 ? SystemInfo.formatBytes(SystemInfo.diskUsed) + " used of " + SystemInfo.formatBytes(SystemInfo.diskTotal) + " on /  ·  " + SystemInfo.formatBytes(SystemInfo.diskAvailable) + " free" : "Unavailable"

            Meter {
                value: SystemInfo.diskPercent / 100
            }

            StyledText {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: SystemInfo.diskTotal > 0 ? Math.round(SystemInfo.diskPercent) + "%" : "—"
                color: Appearance.mutedColor
            }
        }

        SettingRow {
            icon: "thermostat"
            title: "Temperature"
            description: SystemInfo.temperature >= 0 ? "Hottest sensor" + (SystemInfo.cpuTemperature >= 0 ? "  ·  processor " + Math.round(SystemInfo.cpuTemperature) + " °C" : "") : "Install lm_sensors to see temperatures"

            StyledText {
                text: SystemInfo.temperature >= 0 ? Math.round(SystemInfo.temperature) + " °C" : "—"
                color: Appearance.mutedColor
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
