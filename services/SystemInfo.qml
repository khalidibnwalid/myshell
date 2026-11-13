pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string cpuModel: "Loading…"
    property int cpuCores: 0
    property int cpuThreads: 0
    property real memoryTotal: 0
    property real memoryUsed: 0
    property real memoryAvailable: 0
    property real diskTotal: 0
    property real diskUsed: 0
    property real diskAvailable: 0
    property real diskPercent: 0
    property real temperature: -1
    property real cpuTemperature: -1
    property string gpuName: "Loading…"
    // 0–1, averaged over the time between two refreshLive() calls
    property real cpuUsage: 0
    property var cpuSample: null
    property real uptimeSeconds: 0
    property string kernel: ""
    property string hostname: ""
    property string osName: ""
    readonly property string uptimeText: {
        const s = Math.floor(uptimeSeconds);
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        return (d > 0 ? d + "d " : "") + (h > 0 || d > 0 ? h + "h " : "") + m + "m";
    }

    readonly property real memoryPercent: memoryTotal > 0 ? memoryUsed / memoryTotal : 0

    function formatBytes(bytes) {
        if (!Number.isFinite(bytes) || bytes < 0)
            return "Unavailable";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let value = bytes;
        let unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }
        return value.toFixed(unit === 0 ? 0 : 1) + " " + units[unit];
    }

    function formatCapacityRatio(used, total) {
        if (!Number.isFinite(used) || !Number.isFinite(total) || total <= 0)
            return "—";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let unit = 0;
        let divisor = 1;
        while (total / divisor >= 1024 && unit < units.length - 1) {
            divisor *= 1024;
            unit++;
        }
        return (used / divisor).toFixed(2) + "/" + (total / divisor).toFixed(1) + units[unit];
    }

    function field(output, name) {
        const line = output.split(/\r?\n/).find(value => value.startsWith(name + ":"));
        return line ? line.slice(name.length + 1).trim() : "";
    }

    function refresh() {
        memoryProc.running = true;
        cpuProc.running = true;
        diskProc.running = true;
        temperatureProc.running = true;
        gpuProc.running = true;
    }

    // the cheap readings, for a page that updates every couple of seconds
    function refreshLive() {
        memoryProc.running = true;
        diskProc.running = true;
        temperatureProc.running = true;
        liveProc.running = true;
    }

    function readTemperatures(value, results) {
        if (!value || typeof value !== "object")
            return;
        for (const key of Object.keys(value)) {
            const child = value[key];
            if (/^temp\d+_input$/.test(key) && typeof child === "number")
                results.push(child);
            else if (child && typeof child === "object")
                readTemperatures(child, results);
        }
    }

    function readCpuTemperatures(value, results, inCpuSensor) {
        if (!value || typeof value !== "object")
            return;
        for (const key of Object.keys(value)) {
            const child = value[key];
            const cpuSensor = inCpuSensor || /coretemp|k10temp|cpu|zenpower/i.test(key);
            if (cpuSensor && /^temp\d+_input$/.test(key) && typeof child === "number")
                results.push(child);
            else if (child && typeof child === "object")
                readCpuTemperatures(child, results, cpuSensor);
        }
    }

    Process {
        id: memoryProc
        command: ["sh", "-c", "awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {printf \"%.0f %.0f %.0f\", t*1024, (t-a)*1024, a*1024}' /proc/meminfo"]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = text.trim().split(/\s+/).map(Number);
                if (values.length === 3 && values.every(Number.isFinite)) {
                    root.memoryTotal = values[0];
                    root.memoryUsed = values[1];
                    root.memoryAvailable = values[2];
                }
            }
        }
    }

    Process {
        id: cpuProc
        command: ["lscpu"]
        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text;
                const threads = Number(root.field(output, "CPU(s)"));
                const coresPerSocket = Number(root.field(output, "Core(s) per socket"));
                const sockets = Number(root.field(output, "Socket(s)"));
                root.cpuModel = root.field(output, "Model name") || "Unavailable";
                root.cpuThreads = Number.isFinite(threads) ? threads : 0;
                root.cpuCores = coresPerSocket && sockets ? coresPerSocket * sockets : root.cpuThreads;
            }
        }
    }

    Process {
        id: diskProc
        command: ["df", "-B1", "--output=size,used,avail,pcent", "/"]
        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                const row = text.trim().split(/\r?\n/)[1] || "";
                const values = row.trim().split(/\s+/);
                if (values.length >= 4) {
                    root.diskTotal = Number(values[0]) || 0;
                    root.diskUsed = Number(values[1]) || 0;
                    root.diskAvailable = Number(values[2]) || 0;
                    root.diskPercent = Number.parseFloat(values[3]) || 0;
                }
            }
        }
    }

    Process {
        id: temperatureProc
        command: ["sensors", "-j"]
        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const values = [];
                    const cpuValues = [];
                    root.readTemperatures(JSON.parse(text), values);
                    root.readCpuTemperatures(JSON.parse(text), cpuValues, false);
                    root.temperature = values.length ? Math.max(...values) : -1;
                    root.cpuTemperature = cpuValues.length ? Math.max(...cpuValues) : -1;
                } catch (error) {
                    root.temperature = -1;
                    root.cpuTemperature = -1;
                }
            }
        }
    }

    Process {
        id: liveProc
        command: ["sh", "-c", "head -n1 /proc/stat; cut -d' ' -f1 /proc/uptime"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split(/\r?\n/);
                const ticks = (lines[0] || "").trim().split(/\s+/).slice(1).map(Number);
                if (ticks.length >= 5 && ticks.every(Number.isFinite)) {
                    const total = ticks.reduce((a, b) => a + b, 0);
                    const idle = ticks[3] + ticks[4];
                    const last = root.cpuSample;
                    if (last && total > last.total)
                        root.cpuUsage = Math.max(0, Math.min(1, 1 - (idle - last.idle) / (total - last.total)));
                    root.cpuSample = {
                        "total": total,
                        "idle": idle
                    };
                }
                const up = Number(lines[1]);
                if (Number.isFinite(up))
                    root.uptimeSeconds = up;
            }
        }
    }

    Process {
        id: osProc
        running: true
        command: ["sh", "-c", "uname -r; uname -n; . /etc/os-release 2>/dev/null; echo \"$PRETTY_NAME\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split(/\r?\n/);
                root.kernel = (lines[0] || "").trim();
                root.hostname = (lines[1] || "").trim();
                root.osName = (lines[2] || "").trim() || "Linux";
            }
        }
    }

    Process {
        id: gpuProc
        command: ["lspci"]
        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                const devices = text.split(/\r?\n/).map(line => {
                    const match = line.match(/(?:VGA compatible controller|3D controller|Display controller):\s*(.*)/i);
                    return match ? match[1].replace(/\s+\(rev [^)]+\)$/i, "").trim() : "";
                }).filter(Boolean);
                root.gpuName = devices.length
                    ? devices.join(" · ")
                    : (text.trim() ? "No graphics controller reported" : "Unavailable (pciutils is not installed)");
            }
        }
    }

    Component.onCompleted: refresh()
}
