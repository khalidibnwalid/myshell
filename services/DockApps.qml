pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// What the dock shows: the pinned apps (in the user's order), then every running
// app that is not pinned. Windows are grouped by app.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell"
    // desktop entry ids, in dock order
    property var pins: []
    property bool loaded: false

    // id -> { id, entry, name, icon, pinned, windows: [HyprlandToplevel] }
    readonly property var apps: {
        const map = {};
        // re-evaluate when the list of installed apps changes
        DesktopEntries.applications.values;
        for (const id of pins) {
            const entry = DesktopEntries.byId(id);
            map[id] = {
                "id": id,
                "entry": entry,
                "name": entry?.name || id,
                "icon": iconFor(entry, id),
                "pinned": true,
                "windows": []
            };
        }
        for (const t of Hyprland.toplevels.values) {
            const cls = windowClass(t) === "" ? "" : windowId(t);
            if (cls === "")
                continue;
            const entry = DesktopEntries.heuristicLookup(cls);
            const id = entry?.id || cls;
            if (!map[id])
                map[id] = {
                    "id": id,
                    "entry": entry,
                    "name": entry?.name || cls,
                    "icon": iconFor(entry, cls),
                    "pinned": false,
                    "windows": []
                };
            map[id].windows.push(t);
        }
        return map;
    }
    // dock order: pins first, then the other running apps in the order they were opened
    readonly property var order: pins.concat(Object.keys(apps).filter(id => !apps[id].pinned))
    readonly property int pinnedCount: pins.length

    // The shell's own windows share one app id, so Notepad and Processes are told apart by its title and has
    // its own desktop entry (installed by scripts/install-app-icons.sh).
    function windowId(toplevel) {
        const cls = windowClass(toplevel);
        if (toplevel.title === "Notepad" && (cls.endsWith("noctalia-qs") || cls === "quickshell"))
            return "quickshell-notepad";
        const app = Apps.byTitle(toplevel.title);
        if (app && (cls.endsWith("noctalia-qs") || cls === "quickshell"))
            return "quickshell-" + app.id;
        return cls;
    }

    function windowClass(toplevel) {
        return toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "";
    }

    function iconFor(entry, fallback) {
        return Icons.path(entry?.icon || fallback, true) || Icons.path("application-x-executable", true);
    }

    function isPinned(id) {
        return pins.indexOf(id) >= 0;
    }

    // pins the app at `index` (end of the pins when omitted); moves it if already pinned
    function pin(id, index) {
        const rest = pins.filter(p => p !== id);
        const at = index === undefined ? rest.length : Math.max(0, Math.min(rest.length, index));
        rest.splice(at, 0, id);
        pins = rest;
        save();
    }

    function unpin(id) {
        pins = pins.filter(p => p !== id);
        save();
    }

    function launch(id) {
        const entry = apps[id]?.entry;
        if (entry)
            entry.execute();
    }

    function focusWindow(toplevel) {
        if (toplevel.wayland)
            toplevel.wayland.activate();
        else
            HyprCommand.focusWindow("0x" + toplevel.address);
    }

    // Click on a dock icon: launch when nothing is open, otherwise focus the app,
    // moving on to its next window when one of them already has the focus.
    function activate(id) {
        const app = apps[id];
        if (!app)
            return;
        if (app.windows.length === 0) {
            launch(id);
            return;
        }
        const current = app.windows.findIndex(w => w.activated);
        focusWindow(app.windows[(current + 1) % app.windows.length]);
    }

    function closeAll(id) {
        for (const w of apps[id]?.windows ?? []) {
            if (w.wayland)
                w.wayland.close();
        }
    }

    function save() {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/dock.json\"", "sh", stateDir, JSON.stringify(pins)]);
    }

    Process {
        command: ["cat", root.stateDir + "/dock.json"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    if (Array.isArray(data))
                        root.pins = data.filter(id => typeof id === "string");
                } catch (e) {
                    // first run: start with the apps launched most often from the search
                    root.seedPending = true;
                    root.seed();
                }
                root.loaded = true;
            }
        }
    }

    property bool seedPending: false

    function seed() {
        const usage = Search.usageData || {};
        const top = Object.keys(usage).sort((a, b) => usage[b] - usage[a]).slice(0, 5);
        if (!seedPending || top.length === 0)
            return;
        seedPending = false;
        pins = top;
    }

    // the usage file may load after ours
    Connections {
        function onUsageDataChanged() {
            root.seed();
        }

        target: Search
    }
}
