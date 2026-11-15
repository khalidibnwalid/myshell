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
                const fields = {};
                for (const line of output.split(/\r?\n/)) {
                    const at = line.indexOf(":");
                    if (at > 0)
                        fields[line.slice(0, at).trim()] = line.slice(at + 1).trim();
                }
                root.cpuFields = fields;
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
                    root.sensorChips = root.readChips(JSON.parse(text));
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

    // --- the detailed view ----------------------------------------------------
    // every field lscpu reports
    property var cpuFields: ({})
    // per thread: usage 0–1, current and highest speed in MHz; the threads of the
    // efficiency cores on a CPU with two kinds
    property var coreUsage: []
    property var coreFreq: []
    property var coreMaxFreq: []
    property var efficiencyThreads: []
    property var coreSamples: ({})
    // the physical core each thread belongs to
    property var threadCore: []

    // the physical cores: [{ id, label, threads, efficiency, usage, freq, temp }]; temp is -1 when unknown
    readonly property var cores: {
        const byId = {};
        const order = [];
        for (let t = 0; t < coreUsage.length; t++) {
            const id = threadCore[t] !== undefined ? threadCore[t] : t;
            if (!byId[id]) {
                byId[id] = {
                    "id": id,
                    "threads": []
                };
                order.push(id);
            }
            byId[id].threads.push(t);
        }
        const chip = sensorChips.find(c => c.name === "Processor");
        let performance = 0;
        let efficiency = 0;
        return order.sort((a, b) => a - b).map(id => {
            const core = byId[id];
            const eff = efficiencyThreads.length > 0 && efficiencyThreads.indexOf(core.threads[0]) >= 0;
            const mean = list => list.reduce((x, y) => x + y, 0) / list.length;
            const sensor = chip ? chip.items.find(i => i.label === "Core " + id) : null;
            return {
                "id": id,
                "label": efficiencyThreads.length > 0 ? (eff ? "E" + efficiency++ : "P" + performance++) : String(order.indexOf(id)),
                "threads": core.threads,
                "efficiency": eff,
                "usage": mean(core.threads.map(t => coreUsage[t] || 0)),
                "freq": mean(core.threads.map(t => coreFreq[t] || 0)),
                "temp": sensor ? sensor.value : -1
            };
        });
    }
    // /proc/meminfo in bytes, by name
    property var memInfo: ({})
    // [{ name, type, size, used, priority }] in bytes
    property var swaps: []
    // [{ name, driver, busy, vramUsed, vramTotal, temp, power, clock, memClock, fan, pstate }], -1 = unknown
    property var gpus: []
    // [{ name, model, size, kind }]
    property var disks: []
    // [{ source, fstype, size, used, available, mounts: [] }]
    property var filesystems: []
    // [{ name, adapter, items: [{ label, value }] }]
    property var sensorChips: []
    property var machine: ({})
    property string loadAverage: ""
    property int processCount: 0

    readonly property real swapTotal: (memInfo.SwapTotal || 0)
    readonly property real swapUsed: Math.max(0, (memInfo.SwapTotal || 0) - (memInfo.SwapFree || 0))
    readonly property var swapNote: swaps.length === 0 ? "No swap is set up" : ""

    function formatMhz(mhz) {
        if (!Number.isFinite(mhz) || mhz <= 0)
            return "—";
        return mhz >= 1000 ? (mhz / 1000).toFixed(2) + " GHz" : Math.round(mhz) + " MHz";
    }

    // "12-19,22" -> [12, 13, …, 19, 22]
    function parseRanges(text) {
        const out = [];
        for (const part of String(text || "").trim().split(",")) {
            if (part === "")
                continue;
            const range = part.split("-").map(Number);
            if (range.some(isNaN))
                continue;
            for (let i = range[0]; i <= (range[1] ?? range[0]); i++)
                out.push(i);
        }
        return out;
    }

    function chipName(chip) {
        const names = [[/^coretemp|^k10temp|^zenpower/, "Processor"], [/^nvme/, "NVMe drive"], [/^iwlwifi|^mt7|^ath|^rtw/, "Wi-Fi"], [/^acpitz/, "Motherboard"], [/^BAT/, "Battery"], [/^amdgpu|^nouveau|^i915/, "Graphics"], [/^nvidia/, "NVIDIA graphics"], [/^pch_/, "Chipset"], [/^thinkpad|^dell|^asus|^hp/, "Laptop"]];
        for (const pair of names) {
            if (pair[0].test(chip))
                return pair[1];
        }
        return chip.replace(/-(isa|pci|virtual|acpi)-.*$/, "");
    }

    function readChips(data) {
        const out = [];
        for (const chip of Object.keys(data || {})) {
            const body = data[chip];
            if (!body || typeof body !== "object")
                continue;
            const items = [];
            for (const feature of Object.keys(body)) {
                const f = body[feature];
                if (!f || typeof f !== "object")
                    continue;
                const key = Object.keys(f).find(k => /^temp\d+_input$/.test(k));
                if (key && typeof f[key] === "number")
                    items.push({
                        "label": feature,
                        "value": f[key]
                    });
            }
            if (items.length > 0)
                out.push({
                    "name": chipName(chip),
                    "adapter": body.Adapter || "",
                    "items": items
                });
        }
        return out;
    }

    // the numbers that change every moment: cores, memory, graphics, temperatures
    function refreshDetailsLive() {
        coresProc.running = true;
        memDetailProc.running = true;
        gpuDetailProc.running = true;
        temperatureProc.running = true;
        liveProc.running = true;
        machineProc.running = true;
    }

    // what hardly changes: the processor, the drives
    function refreshDetailsStatic() {
        cpuProc.running = true;
        storageProc.running = true;
    }

    Process {
        id: coresProc
        command: ["sh", "-c", "awk '/^cpu[0-9]/ {print \"stat\", substr($1,4), $2, $3, $4, $5, $6, $7, $8}' /proc/stat; for d in /sys/devices/system/cpu/cpu[0-9]*; do n=${d##*cpu}; f=$(cat $d/cpufreq/scaling_cur_freq 2>/dev/null); m=$(cat $d/cpufreq/cpuinfo_max_freq 2>/dev/null); c=$(cat $d/topology/core_id 2>/dev/null); echo \"freq $n ${f:-0} ${m:-0}\"; echo \"core $n ${c:-$n}\"; done; echo \"atom $(cat /sys/devices/cpu_atom/cpus 2>/dev/null)\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const usage = root.coreUsage.slice();
                const freq = root.coreFreq.slice();
                const maxFreq = root.coreMaxFreq.slice();
                const samples = Object.assign({}, root.coreSamples);
                const ids = root.threadCore.slice();
                for (const line of text.split(/\r?\n/)) {
                    const f = line.trim().split(/\s+/);
                    if (f[0] === "stat") {
                        const n = Number(f[1]);
                        const ticks = f.slice(2).map(Number);
                        const total = ticks.reduce((a, b) => a + b, 0);
                        const idle = ticks[3] + (ticks[4] || 0);
                        const last = samples[n];
                        if (last && total > last.total)
                            usage[n] = Math.max(0, Math.min(1, 1 - (idle - last.idle) / (total - last.total)));
                        else if (usage[n] === undefined)
                            usage[n] = 0;
                        samples[n] = {
                            "total": total,
                            "idle": idle
                        };
                    } else if (f[0] === "freq") {
                        const n = Number(f[1]);
                        freq[n] = Number(f[2]) / 1000;
                        maxFreq[n] = Number(f[3]) / 1000;
                    } else if (f[0] === "core") {
                        ids[Number(f[1])] = Number(f[2]);
                    } else if (f[0] === "atom") {
                        root.efficiencyThreads = root.parseRanges(f.slice(1).join(","));
                    }
                }
                root.coreSamples = samples;
                root.threadCore = ids;
                root.coreUsage = usage;
                root.coreFreq = freq;
                root.coreMaxFreq = maxFreq;
            }
        }
    }

    Process {
        id: memDetailProc
        command: ["sh", "-c", "cat /proc/meminfo; echo ---; cat /proc/swaps"]

        stdout: StdioCollector {
            onStreamFinished: {
                const info = {};
                const swapList = [];
                let inSwaps = false;
                for (const line of text.split(/\r?\n/)) {
                    if (line === "---") {
                        inSwaps = true;
                        continue;
                    }
                    if (!inSwaps) {
                        const m = line.match(/^(\w+)(?:\(\w+\))?:\s+(\d+)/);
                        if (m)
                            info[m[1]] = Number(m[2]) * 1024;
                    } else if (line.startsWith("/")) {
                        const f = line.trim().split(/\s+/);
                        if (f.length >= 5)
                            swapList.push({
                                "name": f[0],
                                "type": f[1],
                                "size": Number(f[2]) * 1024,
                                "used": Number(f[3]) * 1024,
                                "priority": Number(f[4])
                            });
                    }
                }
                root.memInfo = info;
                root.swaps = swapList;
            }
        }
    }

    Process {
        id: gpuDetailProc
        command: [Quickshell.shellDir + "/scripts/gpu-info.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                const num = v => (v === undefined || v === "-" || v === "" || isNaN(Number(v))) ? -1 : Number(v);
                const list = [];
                for (const line of text.split(/\r?\n/)) {
                    const f = line.split("\t");
                    if (f[0] !== "gpu" || f.length < 12)
                        continue;
                    list.push({
                        "name": f[1],
                        "driver": f[2],
                        "busy": num(f[3]),
                        "vramUsed": num(f[4]),
                        "vramTotal": num(f[5]),
                        "temp": num(f[6]),
                        "power": num(f[7]),
                        "clock": num(f[8]),
                        "memClock": num(f[9]),
                        "fan": num(f[10]),
                        "pstate": f[11] === "-" ? "" : f[11]
                    });
                }
                root.gpus = list;
            }
        }
    }

    Process {
        id: storageProc
        command: ["sh", "-c", "lsblk -d -b -n -P -o NAME,MODEL,SIZE,TYPE,ROTA,TRAN 2>/dev/null; echo ---; df -B1 -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay --output=source,fstype,size,used,avail,target 2>/dev/null"]
        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                const driveList = [];
                const bySource = {};
                const order = [];
                let inFs = false;
                for (const line of text.split(/\r?\n/)) {
                    if (line === "---") {
                        inFs = true;
                        continue;
                    }
                    if (!inFs) {
                        const kv = {};
                        const pair = /(\w+)="([^"]*)"/g;
                        let m;
                        while ((m = pair.exec(line)) !== null)
                            kv[m[1]] = m[2];
                        if (!kv.NAME || /^(zram|loop|ram)/.test(kv.NAME))
                            continue;
                        const kind = kv.TRAN === "nvme" ? "NVMe SSD" : (kv.TRAN === "usb" ? "USB drive" : (kv.ROTA === "1" ? "Hard disk" : "SSD"));
                        driveList.push({
                            "name": kv.NAME,
                            "model": kv.MODEL.trim(),
                            "size": Number(kv.SIZE),
                            "kind": kind
                        });
                    } else if (line.startsWith("/")) {
                        const f = line.trim().split(/\s+/);
                        if (f.length < 6)
                            continue;
                        const target = f.slice(5).join(" ");
                        if (!bySource[f[0]]) {
                            bySource[f[0]] = {
                                "source": f[0],
                                "fstype": f[1],
                                "size": Number(f[2]),
                                "used": Number(f[3]),
                                "available": Number(f[4]),
                                "mounts": []
                            };
                            order.push(f[0]);
                        }
                        bySource[f[0]].mounts.push(target);
                    }
                }
                root.disks = driveList;
                root.filesystems = order.map(k => bySource[k]);
            }
        }
    }

    Process {
        id: machineProc
        command: ["sh", "-c", "for f in sys_vendor product_name product_version board_name bios_version bios_date; do echo \"$f=$(cat /sys/class/dmi/id/$f 2>/dev/null)\"; done; cat /proc/loadavg; ls /proc | grep -c '^[0-9]'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const info = {};
                const lines = text.trim().split(/\r?\n/);
                for (const line of lines) {
                    const at = line.indexOf("=");
                    if (at > 0 && /^[a-z_]+$/.test(line.slice(0, at)))
                        info[line.slice(0, at)] = line.slice(at + 1).trim();
                }
                root.machine = info;
                const load = lines.find(l => /^\d+\.\d+ \d+\.\d+ \d+\.\d+/.test(l));
                root.loadAverage = load ? load.split(" ").slice(0, 3).join(" · ") : "";
                const count = Number(lines[lines.length - 1]);
                root.processCount = Number.isFinite(count) ? count : 0;
            }
        }
    }

    Component.onCompleted: refresh()
}
