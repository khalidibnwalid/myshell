pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Printers and scanners, as CUPS and SANE have them.
Singleton {
    id: root

    // [{ name, uri, state: "idle" | "printing" | "stopped", enabled, model, reasons, markers: [{ name, level, color }] }]
    property var printers: []
    property string defaultPrinter: ""
    // [{ id, printer, user, size, title, active }]: title and active (being printed now) come from lpq
    property var jobs: []
    // the CUPS service answers
    property bool serviceRunning: true
    property bool loaded: false
    property bool scanAvailable: true
    property var scanners: []

    function refresh() {
        listProc.running = true;
        jobsProc.running = true;
    }

    function refreshScanners() {
        scanProc.running = true;
    }

    function setDefault(name) {
        Quickshell.execDetached(["lpoptions", "-d", name]);
        refreshTimer.restart();
    }

    function testPage(name) {
        Quickshell.execDetached(["lp", "-d", name, "/usr/share/cups/data/default-testpage.pdf"]);
        refreshTimer.restart();
    }

    // only the queue: cheap enough to ask again while Quick Settings shows it
    function refreshJobs() {
        jobsProc.running = true;
    }

    function cancelJob(id) {
        Quickshell.execDetached(["cancel", String(id)]);
        refreshTimer.restart();
    }

    function cancelJobs(name) {
        Quickshell.execDetached(["cancel", "-a", name]);
        refreshTimer.restart();
    }

    // CUPS' own page: add, remove, change drivers and options
    function openAdmin(name) {
        Quickshell.execDetached(["xdg-open", "http://localhost:631/" + (name ? "printers/" + name : "admin")]);
    }

    Timer {
        id: refreshTimer

        interval: 1200
        onTriggered: root.refresh()
    }

    Process {
        id: listProc

        command: ["sh", "-c", "lpstat -p -d -v 2>&1; echo ---; for p in $(lpstat -e 2>/dev/null); do echo \"PRINTER $p\"; ipptool -tv \"ipp://localhost/printers/$p\" get-printer-attributes.test 2>/dev/null | grep -E 'marker-(names|levels|colors) |printer-state-reasons|printer-make-and-model'; done"]
        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                const byName = {};
                const order = [];
                let def = "";
                let part = 0;
                let current = null;
                let last = null;
                root.serviceRunning = !/Connection refused|cups.*not running|Bad file descriptor/i.test(text.split("---")[0]);
                for (const raw of text.split(/\r?\n/)) {
                    if (raw === "---") {
                        part = 1;
                        continue;
                    }
                    if (part === 0) {
                        let m = raw.match(/^printer (\S+) (is idle|now printing|disabled|is stopped)/);
                        if (m) {
                            last = {
                                "name": m[1],
                                "uri": "",
                                "state": m[2] === "now printing" ? "printing" : (m[2] === "is idle" ? "idle" : "stopped"),
                                "enabled": m[2] !== "disabled" && m[2] !== "is stopped",
                                "model": "",
                                "reasons": "",
                                "markers": []
                            };
                            byName[m[1]] = last;
                            order.push(m[1]);
                            continue;
                        }
                        if (raw.startsWith("\t") && last) {
                            last.reasons = raw.trim();
                            continue;
                        }
                        m = raw.match(/^system default destination: (\S+)/);
                        if (m)
                            def = m[1];
                        m = raw.match(/^device for (\S+): (.*)$/);
                        if (m && byName[m[1]])
                            byName[m[1]].uri = m[2];
                    } else {
                        const t = raw.trim();
                        if (t.startsWith("PRINTER ")) {
                            current = byName[t.slice(8)] || null;
                            current && (current.names = [], current.levels = [], current.colors = []);
                        } else if (current) {
                            const m = t.match(/^([\w-]+) \([^)]*\) = (.*)$/);
                            if (!m)
                                continue;
                            if (m[1] === "marker-names")
                                current.names = m[2].split(",");
                            else if (m[1] === "marker-levels")
                                current.levels = m[2].split(",").map(Number);
                            else if (m[1] === "marker-colors")
                                current.colors = m[2].split(",");
                            else if (m[1] === "printer-make-and-model")
                                current.model = m[2];
                        }
                    }
                }
                const list = order.map(n => {
                    const p = byName[n];
                    p.markers = (p.names || []).map((name, i) => ({
                                "name": name,
                                "level": (p.levels || [])[i] ?? -1,
                                "color": (p.colors || [])[i] || ""
                            })).filter(x => x.level >= 0);
                    return p;
                });
                root.printers = list;
                root.defaultPrinter = def;
                root.loaded = true;
            }
        }
    }

    Process {
        id: jobsProc

        // lpstat names the printer of each job, lpq the document and which one is printing
        command: ["sh", "-c", "lpstat -o 2>/dev/null; echo ---; lpq -a 2>/dev/null"]
        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split(/^---$/m);
                const extra = {};
                for (const line of (parts[1] || "").split(/\r?\n/)) {
                    // "active  khalid  12  report final.pdf  1024 bytes"
                    const m = line.match(/^(\S+)\s+(\S+)\s+(\d+)\s+(.*?)\s+(\d+) bytes\s*$/);
                    if (m)
                        extra[m[3]] = {
                            "title": m[4],
                            "active": m[1] === "active"
                        };
                }
                const list = [];
                for (const line of parts[0].split(/\r?\n/)) {
                    const m = line.match(/^(\S+)-(\d+)\s+(\S+)\s+(\d+)/);
                    if (m)
                        list.push({
                            "id": Number(m[2]),
                            "printer": m[1],
                            "user": m[3],
                            "size": Number(m[4]),
                            "title": extra[m[2]]?.title ?? "",
                            "active": extra[m[2]]?.active ?? false
                        });
                }
                root.jobs = list;
            }
        }
    }

    Process {
        id: scanProc

        command: ["sh", "-c", "command -v scanimage >/dev/null || { echo MISSING; exit 0; }; scanimage -L 2>&1"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "MISSING") {
                    root.scanAvailable = false;
                    root.scanners = [];
                    return;
                }
                root.scanAvailable = true;
                const list = [];
                for (const line of text.split(/\r?\n/)) {
                    const m = line.match(/^device `([^']+)' is a (.*)$/);
                    if (m)
                        list.push({
                            "device": m[1],
                            "name": m[2]
                        });
                }
                root.scanners = list;
            }
        }
    }

    // the sidebar hides pages for hardware that is not there, so look at startup and now and then
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        refresh();
        refreshScanners();
    }
}
