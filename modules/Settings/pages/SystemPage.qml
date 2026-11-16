import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page

    // Summary is the short look; Detailed adds every reading the computer offers
    property bool detailed: false
    readonly property color hot: "#f2b8b5"
    readonly property var driverIcons: ({
            "Graphics": "developer_board",
            "Network": "lan",
            "Audio": "speaker",
            "Storage": "hard_drive",
            "Bluetooth": "bluetooth",
            "USB": "usb",
            "Other": "memory"
        })

    function pct(v) {
        return Math.round(Math.max(0, v) * 100) + "%";
    }

    function gb(bytes) {
        return SystemInfo.formatBytes(bytes);
    }

    function tempColor(t) {
        return t >= 85 ? page.hot : Appearance.accentColor;
    }

    // how many cores of each kind, on a processor that has two
    readonly property string coreMix: {
        const e = SystemInfo.efficiencyThreads.length;
        const threads = SystemInfo.cpuThreads;
        if (e === 0 || threads === 0)
            return "";
        const pThreads = threads - e;
        const smt = Number(SystemInfo.cpuFields["Thread(s) per core"] || 1);
        const pCores = Math.round(pThreads / Math.max(1, smt));
        return pCores + " performance + " + e + " efficiency cores";
    }

    // the sensors that are not the processor's (those sit with the cores)
    readonly property var otherSensors: {
        const out = [];
        for (const chip of SystemInfo.sensorChips) {
            if (chip.name === "Processor")
                continue;
            for (const item of chip.items)
                out.push({
                    "name": chip.name,
                    "label": item.label,
                    "value": item.value
                });
        }
        return out;
    }

    // asked for by a Quick Settings tile (CPU): open on the Detailed look
    function takeDetailedRequest() {
        if (WindowManager.settingsDetailed) {
            WindowManager.settingsDetailed = false;
            detailed = true;
        }
    }

    title: "System"
    subtitle: SystemInfo.hostname
    Component.onCompleted: {
        takeDetailedRequest();
        SystemInfo.refresh();
        SystemInfo.refreshLive();
    }

    Connections {
        function onSettingsDetailedChanged() {
            page.takeDetailedRequest();
        }

        target: WindowManager
    }
    onDetailedChanged: {
        if (detailed) {
            Drivers.refresh();
            SystemInfo.refreshDetailsStatic();
            SystemInfo.refreshDetailsLive();
        }
    }

    headerActions: [
        Segmented {
            model: [
                {
                    "label": "Summary",
                    "value": false
                },
                {
                    "label": "Detailed",
                    "value": true
                }
            ]
            value: page.detailed
            onSelected: v => page.detailed = v
        }
    ]

    // the page only exists while it is shown, so this stops on its own
    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            SystemInfo.refreshLive();
            if (page.detailed)
                SystemInfo.refreshDetailsLive();
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: page.detailed
        onTriggered: SystemInfo.refreshDetailsStatic()
    }

    SettingGroup {
        visible: !page.detailed
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
                    visible: SystemInfo.temperature >= 0
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
        visible: !page.detailed
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

    // ------------------------------------------------------------------ detailed
    SettingGroup {
        visible: page.detailed
        title: "Processor"

        SettingRow {
            icon: "memory"
            title: SystemInfo.cpuModel
            description: SystemInfo.cpuCores + " cores · " + SystemInfo.cpuThreads + " threads" + (page.coreMix !== "" ? "  ·  " + page.coreMix : "")

            StyledText {
                visible: SystemInfo.cpuTemperature >= 0
                text: Math.round(SystemInfo.cpuTemperature) + "°C"
                color: page.tempColor(SystemInfo.cpuTemperature)
            }
        }

        MeterRow {
            icon: "speed"
            title: "Usage"
            detail: page.pct(SystemInfo.cpuUsage) + "  ·  " + SystemInfo.formatMhz(SystemInfo.coreFreq.length ? SystemInfo.coreFreq.reduce((a, b) => a + b, 0) / SystemInfo.coreFreq.length : 0) + " of " + SystemInfo.formatMhz(Number(SystemInfo.cpuFields["CPU max MHz"]))
            value: SystemInfo.cpuUsage
            note: ["Load " + SystemInfo.loadAverage, SystemInfo.processCount + " processes", ["L2", "L3"].filter(k => SystemInfo.cpuFields[k + " cache"]).map(k => k + " " + SystemInfo.cpuFields[k + " cache"].replace(/ \(.*\)/, "")).join(" "), SystemInfo.cpuFields["Virtualization"] ? SystemInfo.cpuFields["Virtualization"] : ""].filter(x => x).join("  ·  ")
        }

        // every core: its usage, speed and temperature
        SettingCard {
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 22
                rowSpacing: 10

                Repeater {
                    model: SystemInfo.cores

                    delegate: RowLayout {
                        id: coreCell

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 8

                        StyledText {
                            Layout.preferredWidth: 26
                            text: coreCell.modelData.label
                            color: coreCell.modelData.efficiency ? Appearance.mutedColor : Appearance.fgColor
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Meter {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            value: coreCell.modelData.usage
                            fillColor: coreCell.modelData.temp >= 85 ? page.hot : Appearance.accentColor
                        }

                        StyledText {
                            Layout.preferredWidth: 150
                            horizontalAlignment: Text.AlignRight
                            text: page.pct(coreCell.modelData.usage) + "  ·  " + SystemInfo.formatMhz(coreCell.modelData.freq) + (coreCell.modelData.temp >= 0 ? "  ·  " + Math.round(coreCell.modelData.temp) + "°" : "")
                            color: Appearance.mutedColor
                            font.pixelSize: 11
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: page.coreMix !== ""
                text: "P performance cores (two threads each), E efficiency cores"
                color: Appearance.mutedColor
                font.pixelSize: 11
            }
        }
    }

    SettingGroup {
        visible: page.detailed
        title: "Memory"

        MeterRow {
            icon: "memory_alt"
            title: "Memory"
            detail: page.gb(SystemInfo.memoryUsed) + " of " + page.gb(SystemInfo.memoryTotal)
            value: SystemInfo.memoryPercent
            note: ["Available " + page.gb(SystemInfo.memoryAvailable), "Cached " + page.gb((SystemInfo.memInfo.Cached || 0) + (SystemInfo.memInfo.SReclaimable || 0)), "Shared " + page.gb(SystemInfo.memInfo.Shmem || 0)].join("  ·  ")
        }

        MeterRow {
            visible: SystemInfo.swaps.length > 0
            icon: "swap_horiz"
            title: "Swap"
            detail: page.gb(SystemInfo.swapUsed) + " of " + page.gb(SystemInfo.swapTotal)
            value: SystemInfo.swapTotal > 0 ? SystemInfo.swapUsed / SystemInfo.swapTotal : 0
            note: SystemInfo.swaps.map(w => (w.name.indexOf("zram") >= 0 ? "zram (compressed memory)" : w.name) + " " + page.gb(w.used) + " of " + page.gb(w.size)).join("  ·  ") + "  ·  higher priority first"
        }

    }

    Repeater {
        model: page.detailed ? SystemInfo.gpus : []

        delegate: SettingGroup {
            id: gpuGroup

            required property var modelData

            title: "Graphics"

            SettingRow {
                icon: "developer_board"
                title: gpuGroup.modelData.name
                description: "Driver " + (gpuGroup.modelData.driver || "unknown") + (gpuGroup.modelData.pstate ? "  ·  power state " + gpuGroup.modelData.pstate : "") + (gpuGroup.modelData.vramTotal <= 0 ? "  ·  shares the system memory" : "")
            }

            MeterRow {
                visible: gpuGroup.modelData.busy >= 0
                icon: "speed"
                title: "Usage"
                detail: gpuGroup.modelData.busy + "%"
                value: gpuGroup.modelData.busy / 100
            }

            MeterRow {
                visible: gpuGroup.modelData.vramTotal > 0
                icon: "memory_alt"
                title: "Video memory"
                detail: page.gb(gpuGroup.modelData.vramUsed) + " of " + page.gb(gpuGroup.modelData.vramTotal)
                value: gpuGroup.modelData.vramTotal > 0 ? gpuGroup.modelData.vramUsed / gpuGroup.modelData.vramTotal : 0
            }

            SettingRow {
                visible: gpuGroup.modelData.temp >= 0 || gpuGroup.modelData.power >= 0 || gpuGroup.modelData.clock > 0 || gpuGroup.modelData.fan >= 0
                icon: "monitor_heart"
                title: "Status"
                description: [gpuGroup.modelData.clock > 0 ? "Core " + SystemInfo.formatMhz(gpuGroup.modelData.clock) + (gpuGroup.modelData.memClock > 0 ? ", memory " + SystemInfo.formatMhz(gpuGroup.modelData.memClock) : "") : "", gpuGroup.modelData.power >= 0 ? gpuGroup.modelData.power.toFixed(1) + " W" : "", gpuGroup.modelData.fan >= 0 ? "Fan " + gpuGroup.modelData.fan + "%" : ""].filter(x => x).join("  ·  ")

                StyledText {
                    visible: gpuGroup.modelData.temp >= 0
                    text: gpuGroup.modelData.temp + "°C"
                    color: page.tempColor(gpuGroup.modelData.temp)
                }
            }
        }
    }

    SettingGroup {
        visible: page.detailed
        title: "Storage"

        Repeater {
            model: SystemInfo.disks

            delegate: SettingRow {
                id: diskRow

                required property var modelData

                icon: "hard_drive"
                title: modelData.model || modelData.name
                description: modelData.kind + "  ·  /dev/" + modelData.name

                StyledText {
                    text: page.gb(diskRow.modelData.size)
                    color: Appearance.mutedColor
                }
            }
        }

        Repeater {
            model: SystemInfo.filesystems

            delegate: MeterRow {
                id: fsRow

                required property var modelData

                icon: "folder"
                title: modelData.mounts.length > 3 ? modelData.mounts.slice(0, 3).join(", ") + " +" + (modelData.mounts.length - 3) : modelData.mounts.join(", ")
                detail: page.gb(modelData.used) + " of " + page.gb(modelData.size)
                value: modelData.size > 0 ? modelData.used / modelData.size : 0
                barColor: modelData.size > 0 && modelData.used / modelData.size >= 0.9 ? page.hot : Appearance.accentColor
                note: modelData.source + "  ·  " + modelData.fstype + "  ·  " + page.gb(modelData.available) + " free"
            }
        }
    }

    SettingGroup {
        visible: page.detailed && page.otherSensors.length > 0
        title: "Temperatures"

        Repeater {
            model: page.otherSensors

            delegate: SettingRow {
                id: sensorRow

                required property var modelData

                icon: "thermostat"
                title: modelData.name
                description: modelData.label

                StyledText {
                    text: Math.round(sensorRow.modelData.value) + "°C"
                    color: page.tempColor(sensorRow.modelData.value)
                }
            }
        }
    }

    SettingGroup {
        visible: page.detailed
        title: "Drivers"

        Repeater {
            model: Drivers.devices

            delegate: SettingRow {
                required property var modelData

                icon: page.driverIcons[modelData.kind] || "memory"
                title: modelData.name
                description: modelData.kind + "  ·  " + (modelData.driver !== "" ? "driver " + modelData.driver : "no driver loaded")
            }
        }

        SettingRow {
            visible: Drivers.hasChwd && Drivers.profiles.length > 0
            icon: "deployed_code"
            title: "Hardware profile"
            description: Drivers.profiles.map(p => p.name).join(", ") + "  ·  to change: sudo chwd -i <profile>"
        }

        SettingRow {
            icon: "memory"
            title: "Kernel and firmware"
            description: ["Linux " + Drivers.kernel, Drivers.moduleCount + " modules loaded", Drivers.nvidiaVersion !== "" ? "NVIDIA " + Drivers.nvidiaVersion : "", Drivers.microcode !== "" ? "microcode " + Drivers.microcode : ""].filter(x => x).join("  ·  ")
        }

        SettingRow {
            visible: Drivers.hasFirmwareTool
            icon: "system_update"
            title: "Firmware updates"
            description: "Check from a terminal: fwupdmgr refresh && fwupdmgr get-updates"
        }
    }

    SettingGroup {
        visible: page.detailed
        title: "This computer"

        SettingRow {
            icon: "computer"
            title: [SystemInfo.machine.sys_vendor, SystemInfo.machine.product_version || SystemInfo.machine.product_name].filter(x => x).join(" ") || SystemInfo.hostname
            description: [SystemInfo.machine.product_name, SystemInfo.machine.bios_version ? "BIOS " + SystemInfo.machine.bios_version + (SystemInfo.machine.bios_date ? " (" + SystemInfo.machine.bios_date + ")" : "") : ""].filter(x => x).join("  ·  ")
        }

        SettingRow {
            icon: "deployed_code"
            title: SystemInfo.osName
            description: (SystemInfo.kernel ? "Linux " + SystemInfo.kernel : "") + "  ·  up " + SystemInfo.uptimeText
        }
    }
}
