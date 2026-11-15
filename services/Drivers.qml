pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which driver runs each piece of hardware, and which hardware profile is installed.
// Changing a driver needs administrator rights, so this only reads.
Singleton {
    id: root

    // [{ slot, kind, name, driver, modules: [] }]
    property var devices: []
    // hardware profiles installed with chwd (CachyOS), [{ name, priority }]
    property var profiles: []
    property bool hasChwd: true
    property bool hasFirmwareTool: true
    property string kernel: ""
    property string microcode: ""
    property string nvidiaVersion: ""
    property int moduleCount: 0
    property bool loaded: false

    function refresh() {
        pciProc.running = true;
        infoProc.running = true;
        chwdProc.running = true;
    }

    function kindOf(text) {
        if (/VGA|3D controller|Display controller/i.test(text))
            return "Graphics";
        if (/Ethernet|Network controller|Wireless/i.test(text))
            return "Network";
        if (/Audio|Multimedia/i.test(text))
            return "Audio";
        if (/Non-Volatile|SATA|RAID|Mass storage|NVM/i.test(text))
            return "Storage";
        if (/USB|FireWire|Thunderbolt/i.test(text))
            return "USB";
        if (/Bluetooth/i.test(text))
            return "Bluetooth";
        return "Other";
    }

    Process {
        id: pciProc

        command: ["lspci", "-k"]
        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                let cur = null;
                for (const line of text.split(/\r?\n/)) {
                    if (line === "")
                        continue;
                    if (!line.startsWith("\t") && !line.startsWith(" ")) {
                        const sp = line.indexOf(" ");
                        const rest = line.slice(sp + 1);
                        const at = rest.indexOf(": ");
                        cur = {
                            "slot": line.slice(0, sp),
                            "kind": root.kindOf(rest.slice(0, at)),
                            "name": rest.slice(at + 2).replace(/ \(rev [^)]+\)$/, ""),
                            "driver": "",
                            "modules": []
                        };
                        list.push(cur);
                    } else if (cur) {
                        const t = line.trim();
                        if (t.startsWith("Kernel driver in use:"))
                            cur.driver = t.slice(21).trim();
                        else if (t.startsWith("Kernel modules:"))
                            cur.modules = t.slice(15).split(",").map(x => x.trim());
                    }
                }
                const order = ["Graphics", "Network", "Audio", "Storage", "Bluetooth", "USB", "Other"];
                list.sort((a, b) => order.indexOf(a.kind) - order.indexOf(b.kind));
                root.devices = list;
                root.loaded = true;
            }
        }
    }

    Process {
        id: infoProc

        command: ["sh", "-c", "uname -r; grep -m1 -i 'microcode' /proc/cpuinfo | sed 's/.*: //'; nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1; lsmod | tail -n +2 | wc -l; command -v fwupdmgr >/dev/null && echo fwupd || echo nofwupd"]

        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split(/\r?\n/);
                root.kernel = (l[0] || "").trim();
                root.microcode = (l[1] || "").trim();
                root.nvidiaVersion = (l[2] || "").trim();
                root.moduleCount = Number(l[3]) || 0;
                root.hasFirmwareTool = (l[4] || "").trim() === "fwupd";
            }
        }
    }

    Process {
        id: chwdProc

        command: ["sh", "-c", "command -v chwd >/dev/null || { echo MISSING; exit 0; }; chwd --list-installed 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "MISSING") {
                    root.hasChwd = false;
                    root.profiles = [];
                    return;
                }
                root.hasChwd = true;
                const list = [];
                for (const line of text.split(/\r?\n/)) {
                    const m = line.match(/│\s*([\w.+-]+)\s*┆\s*(\d+)/);
                    if (m && m[1] !== "Name")
                        list.push({
                            "name": m[1],
                            "priority": Number(m[2])
                        });
                }
                root.profiles = list;
            }
        }
    }
}
