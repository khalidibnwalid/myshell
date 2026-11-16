pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The running processes: what each uses, grouped by program, and ending them.
// One sample = `ps` (who, memory, command line) + the CPU time of every process from /proc;
// the CPU share is the change since the previous sample, so it is read only while the window
// is open (the window starts and stops `active`).
Singleton {
    id: root

    property bool active: false
    readonly property int interval: 2000

    // shown rows: { key, name, count, pids, cpu (% of one core), mem (bytes), user, detail }
    property var list: []
    property string query: ""
    property string sortKey: "cpu"
    property bool sortDescending: true
    property bool grouped: true
    property bool onlyMine: true
    property int count: 0
    property string status: ""

    readonly property string me: Quickshell.env("USER") || ""
    property var procs: []
    property var lastTicks: ({})
    property double lastTime: 0
    property int clockTicks: 100

    // the sample: clock ticks per second, `ps`, a marker, then "pid ticks" per process
    readonly property string sampleScript: "getconf CLK_TCK; ps -eo pid=,user:32=,rss=,args=; echo @@; "
        + "awk '{ j = length($0); while (j > 0 && substr($0, j, 1) != \")\") j--; split(substr($0, j + 2), a, \" \"); print $1, a[12] + a[13] }' /proc/[0-9]*/stat 2>/dev/null"

    function nameOf(args) {
        if (args.startsWith("["))
            return args.replace(/^\[|\].*$/g, "");
        const first = args.split(" ")[0];
        const base = first.substring(first.lastIndexOf("/") + 1);
        return base === "" ? first : base;
    }

    function parse(text) {
        const lines = text.split("\n");
        const ticks = {};
        const found = [];
        let afterMarker = false;
        let tick = 100;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (i === 0) {
                tick = parseInt(line) || 100;
                continue;
            }
            if (line === "@@") {
                afterMarker = true;
                continue;
            }
            if (afterMarker) {
                const p = line.split(" ");
                if (p.length === 2)
                    ticks[p[0]] = parseInt(p[1]);
                continue;
            }
            const m = /^\s*(\d+)\s+(\S+)\s+(\d+)\s+(.*)$/.exec(line);
            if (m)
                found.push({
                    "pid": parseInt(m[1]),
                    "user": m[2],
                    "mem": parseInt(m[3]) * 1024,
                    "args": m[4],
                    "name": nameOf(m[4])
                });
        }
        const now = Date.now();
        const seconds = lastTime > 0 ? (now - lastTime) / 1000 : 0;
        for (const p of found) {
            const before = lastTicks[p.pid];
            const t = ticks[p.pid];
            p.cpu = seconds > 0 && before !== undefined && t !== undefined ? Math.max(0, (t - before) / tick / seconds * 100) : 0;
        }
        root.clockTicks = tick;
        root.lastTicks = ticks;
        root.lastTime = now;
        root.procs = found;
        rebuild();
    }

    function compare(a, b) {
        let r;
        if (sortKey === "name")
            r = a.name.localeCompare(b.name);
        else
            r = a[sortKey] - b[sortKey];
        return sortDescending ? -r : r;
    }

    function rebuild() {
        const q = query.trim().toLowerCase();
        const mine = onlyMine ? procs.filter(p => p.user === me) : procs;
        const matching = q === "" ? mine : mine.filter(p => p.name.toLowerCase().includes(q) || p.args.toLowerCase().includes(q) || String(p.pid) === q);
        let rows;
        if (grouped) {
            const groups = {};
            for (const p of matching) {
                let g = groups[p.name];
                if (!g) {
                    g = {
                        "key": p.name,
                        "name": p.name,
                        "count": 0,
                        "pids": [],
                        "cpu": 0,
                        "mem": 0,
                        "pid": p.pid,
                        "user": p.user,
                        "detail": p.args
                    };
                    groups[p.name] = g;
                }
                g.count++;
                g.pids.push(p.pid);
                g.cpu += p.cpu;
                g.mem += p.mem;
                g.pid = Math.min(g.pid, p.pid);
            }
            rows = Object.keys(groups).map(k => groups[k]);
        } else {
            rows = matching.map(p => ({
                        "key": String(p.pid),
                        "name": p.name,
                        "count": 1,
                        "pids": [p.pid],
                        "cpu": p.cpu,
                        "mem": p.mem,
                        "pid": p.pid,
                        "user": p.user,
                        "detail": p.args
                    }));
        }
        rows.sort(compare);
        root.count = procs.length;
        root.list = rows;
    }

    function sortBy(key) {
        if (sortKey === key) {
            sortDescending = !sortDescending;
        } else {
            sortKey = key;
            sortDescending = key !== "name" && key !== "pid" ? true : false;
        }
        rebuild();
    }

    // a program that must not be ended from here: the shell itself, Hyprland, the first process
    function protectedRow(row) {
        return !row || row.pids.indexOf(1) >= 0 || row.pids.indexOf(Quickshell.processId) >= 0 || /^(Hyprland|hyprland|quickshell|qs|systemd)$/.test(row.name);
    }

    function refresh() {
        if (!sampler.running)
            sampler.running = true;
    }

    function end(row, force) {
        if (protectedRow(row))
            return;
        killer.row = row;
        killer.command = ["kill", "-s", force ? "KILL" : "TERM"].concat(row.pids.map(String));
        killer.running = true;
    }

    function say(text) {
        status = text;
        statusTimer.restart();
    }

    onQueryChanged: rebuild()
    onGroupedChanged: rebuild()
    onOnlyMineChanged: rebuild()
    onActiveChanged: {
        if (active) {
            lastTime = 0;
            refresh();
        } else {
            // a stopped window forgets the old sample, so the next first one does not look like a spike
            lastTicks = ({});
        }
    }

    Process {
        id: sampler

        command: ["sh", "-c", root.sampleScript]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    Process {
        id: killer

        property var row: null

        onExited: code => {
            const name = row ? row.name : "";
            if (code === 0)
                root.say("Sent to " + name);
            else
                root.say("Could not end " + name + " (it belongs to someone else, or has already gone)");
            refreshSoon.restart();
        }
    }

    Timer {
        id: refreshSoon

        interval: 500
        onTriggered: root.refresh()
    }

    Timer {
        id: statusTimer

        interval: 4000
        onTriggered: root.status = ""
    }
}
