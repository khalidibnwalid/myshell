pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Drives and what is on them. Mounting and ejecting go through udisks, so no password
// is asked for removable drives. There is no formatting on purpose.
Singleton {
    id: root

    // [{ name, path, model, size, kind, removable, health, parts: [{ path, name, label, fstype, size, used, mounts, system }] }]
    property var drives: []
    property bool loaded: false
    // path of the part being mounted or unmounted
    property string busy: ""

    function refresh() {
        listProc.running = true;
        healthProc.running = true;
    }

    function run(path, args, failTitle) {
        busy = path;
        actionProc.failTitle = failTitle;
        actionProc.command = args;
        actionProc.running = true;
    }

    function mount(path) {
        run(path, ["udisksctl", "mount", "-b", path], "Couldn't mount");
    }

    function unmount(path) {
        run(path, ["udisksctl", "unmount", "-b", path], "Couldn't unmount");
    }

    // unmounts everything on the drive, then powers it off so it can be unplugged
    function eject(drive) {
        busy = drive.path;
        const unmounts = drive.parts.filter(p => p.mounts.length > 0).map(p => "udisksctl unmount -b " + p.path).join(" && ");
        actionProc.failTitle = "Couldn't eject";
        actionProc.command = ["sh", "-c", (unmounts !== "" ? unmounts + " && " : "") + "udisksctl power-off -b " + drive.path];
        actionProc.running = true;
    }

    function openFolder(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function formatKind(d) {
        if (d.tran === "nvme")
            return "NVMe SSD";
        if (d.tran === "usb")
            return d.rm ? "USB drive" : "USB disk";
        if (d.tran === "mmc" || /^mmcblk/.test(d.name))
            return "SD card";
        if (d.rota)
            return "Hard disk";
        return "SSD";
    }

    // the mounts the system needs; they are not offered for unmounting
    function isSystemMount(path) {
        return /^(\/|\/boot|\/boot\/efi|\/efi|\/home|\/var|\/usr|\/nix\/store|\[SWAP\])$/.test(path);
    }

    Process {
        id: actionProc

        property string failTitle: ""

        stderr: StdioCollector {
            id: actionErrors
        }

        onExited: code => {
            root.busy = "";
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "Settings", actionProc.failTitle, actionErrors.text.trim().split("\n")[0] || "The drive is busy or needs permission"]);
            root.refresh();
        }
    }

    Process {
        id: listProc

        command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,MODEL,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,RM,ROTA,TRAN,FSUSED,PARTLABEL"]

        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const out = [];
                for (const d of data.blockdevices || []) {
                    if (d.type !== "disk" || /^(zram|loop|ram)/.test(d.name))
                        continue;
                    const parts = [];
                    const addPart = p => {
                        parts.push({
                            "path": p.path,
                            "name": p.name,
                            "label": p.label || p.partlabel || "",
                            "fstype": p.fstype || "",
                            "size": Number(p.size) || 0,
                            "used": p.fsused !== null && p.fsused !== undefined ? Number(p.fsused) : -1,
                            "mounts": (p.mountpoints || []).filter(m => m),
                            "system": (p.mountpoints || []).some(m => m && root.isSystemMount(m))
                        });
                    };
                    if (d.fstype)
                        addPart(d);
                    for (const p of d.children || [])
                        addPart(p);
                    const old = root.drives.find(x => x.path === d.path);
                    out.push({
                        "name": d.name,
                        "path": d.path,
                        "model": (d.model || "").trim(),
                        "size": Number(d.size) || 0,
                        "kind": root.formatKind(d),
                        "removable": d.rm === true || d.tran === "usb",
                        "health": old ? old.health : "",
                        "parts": parts
                    });
                }
                root.drives = out;
                root.loaded = true;
            }
        }
    }

    // S.M.A.R.T. health; reading it usually needs administrator rights
    Process {
        id: healthProc

        command: ["sh", "-c", "for d in $(lsblk -dn -o PATH -e7,252 2>/dev/null); do echo \"$d $(smartctl -H $d 2>&1 | grep -E 'PASSED|FAILED|Permission denied|result' | head -1)\"; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const health = {};
                for (const line of text.split(/\r?\n/)) {
                    const sp = line.indexOf(" ");
                    if (sp < 0)
                        continue;
                    const rest = line.slice(sp + 1);
                    health[line.slice(0, sp)] = /PASSED|OK/.test(rest) ? "good" : (/FAILED/.test(rest) ? "bad" : "unknown");
                }
                root.drives = root.drives.map(d => Object.assign({}, d, {
                        "health": health[d.path] || d.health || "unknown"
                    }));
            }
        }
    }

    Component.onCompleted: refresh()
}
