import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    title: "System"
    Component.onCompleted: SystemInfo.refresh()

    SettingRow {
        Layout.fillWidth: true
        first: true
        title: "Processor"
        description: SystemInfo.cpuModel

        RowLayout {
            spacing: 4

            StyledText {
                text: SystemInfo.cpuCores > 0
                    ? SystemInfo.cpuCores + " cores · " + SystemInfo.cpuThreads + " threads"
                    : "Unavailable"
                color: Appearance.mutedColor
                font.pixelSize: 12
            }

            IconButton {
                size: 32
                iconSize: 17
                icon: "refresh"
                onClicked: SystemInfo.refresh()
            }
        }
    }

    SettingRow {
        Layout.fillWidth: true
        title: "Memory"
        description: SystemInfo.memoryTotal > 0
            ? SystemInfo.formatBytes(SystemInfo.memoryUsed) + " used of " + SystemInfo.formatBytes(SystemInfo.memoryTotal)
            : "Unavailable"

        StyledText {
            text: SystemInfo.memoryTotal > 0 ? Math.round(SystemInfo.memoryPercent * 100) + "%" : "—"
            color: Appearance.mutedColor
        }
    }

    SettingRow {
        Layout.fillWidth: true
        title: "Storage"
        description: SystemInfo.diskTotal > 0
            ? SystemInfo.formatBytes(SystemInfo.diskUsed) + " used of " + SystemInfo.formatBytes(SystemInfo.diskTotal) + " on /"
            : "Unavailable"

        StyledText {
            text: SystemInfo.diskTotal > 0 ? Math.round(SystemInfo.diskPercent) + "%" : "—"
            color: Appearance.mutedColor
        }
    }

    SettingRow {
        Layout.fillWidth: true
        title: "Graphics"
        description: SystemInfo.gpuName
    }

    SettingRow {
        Layout.fillWidth: true
        last: true
        title: "Temperature"
        description: "Highest temperature reported by available sensors"

        StyledText {
            text: SystemInfo.temperature >= 0 ? Math.round(SystemInfo.temperature) + " °C" : "Unavailable"
            color: Appearance.mutedColor
        }
    }
}
