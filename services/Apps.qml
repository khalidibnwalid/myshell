pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's own apps. Each app is a folder apps/<App>/ with an app.json (id, name, icon, window, search
// words, how it starts), and everything that has to know about the apps reads these files instead of
// naming them: the loader in shell.qml, the launcher, the dock, the desktop entries.
//   mode "inline":  the shell loads the app's `entry` file; the app's window is shown by open(id)
//   mode "process": the app is a program of its own (`process`), started and stopped by its `ctl` script;
//                   the shell loads only the `entry` file, which holds its shortcuts
// An app listed in Config.apps.disabled is not loaded, not found by the launcher and has no desktop entry.
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir + "/apps"
    // every app found, with its folder in `dir`
    property var manifests: []
    property bool loaded: false
    readonly property var disabledIds: Config.apps?.disabled ?? []
    readonly property var enabled: manifests.filter(m => disabledIds.indexOf(m.id) < 0)
    // the inline apps whose window is open
    property var openIds: ({})

    // an inline app that is already open is asked to come to the front
    signal raiseRequested(string id)

    function manifest(id) {
        return manifests.find(m => m.id === id) ?? null;
    }

    function isEnabled(id) {
        return manifest(id) !== null && disabledIds.indexOf(id) < 0;
    }

    function byTitle(title) {
        return enabled.find(m => m.window && m.window.title === title) ?? null;
    }

    function isOpen(id) {
        return openIds[id] === true;
    }

    function setOpen(id, on) {
        const next = Object.assign({}, openIds);
        if (on)
            next[id] = true;
        else
            delete next[id];
        openIds = next;
    }

    // runs the command of a process app: its ctl script starts the program when the command needs it
    function control(m, args) {
        Quickshell.execDetached([m.dir + "/" + (m.ctl || "scripts/ctl.sh")].concat(args));
    }

    function open(id) {
        const m = manifest(id);
        if (!m || !isEnabled(id))
            return;
        if (m.mode === "process")
            control(m, ["open"]);
        else if (isOpen(id))
            raiseRequested(id);
        else
            setOpen(id, true);
    }

    function close(id) {
        const m = manifest(id);
        if (!m)
            return;
        if (m.mode === "process")
            control(m, ["close"]);
        else
            setOpen(id, false);
    }

    function toggle(id) {
        const m = manifest(id);
        if (!m || !isEnabled(id))
            return;
        if (m.mode === "process")
            control(m, ["toggle"]);
        else if (isOpen(id))
            setOpen(id, false);
        else
            open(id);
    }

    // switches an app on or off (the loader stops one that is switched off, however it was switched off)
    function setEnabled(id, on) {
        if (!manifest(id))
            return;
        const rest = disabledIds.filter(x => x !== id);
        if (!on)
            rest.push(id);
        Config.setIn("apps", "disabled", rest);
    }

    // The loader took the app away (switched off): an inline app stops what runs without its window, a
    // process app is told to quit.
    function released(m, item) {
        if (m.mode === "process")
            control(m, ["quit"]);
        else
            setOpen(m.id, false);
        if (item && item.shutdown)
            item.shutdown();
    }

    // the icons and desktop entries follow the manifests and the list of disabled apps
    function installEntries() {
        if (!loaded)
            return;
        Quickshell.execDetached([Quickshell.shellDir + "/scripts/install-app-icons.sh", Quickshell.shellDir].concat(disabledIds));
    }

    function refresh() {
        if (!scanProc.running)
            scanProc.running = true;
    }

    function parse(text) {
        const out = [];
        for (const chunk of text.split("@@")) {
            const at = chunk.indexOf("\n");
            if (at < 0)
                continue;
            const dir = chunk.slice(0, at).trim();
            try {
                const m = JSON.parse(chunk.slice(at + 1));
                if (typeof m.id === "string" && typeof m.name === "string" && typeof m.entry === "string") {
                    m.dir = dir;
                    out.push(m);
                }
            } catch (e) {
                console.warn("Apps: " + dir + "/app.json cannot be read: " + e);
            }
        }
        return out;
    }

    onDisabledIdsChanged: installTimer.restart()

    Timer {
        id: installTimer

        interval: 500
        onTriggered: root.installEntries()
    }

    Process {
        id: scanProc

        command: ["sh", "-c", "for f in \"$1\"/*/app.json; do [ -f \"$f\" ] || continue; printf '@@%s\\n' \"$(dirname \"$f\")\"; cat \"$f\"; echo; done", "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                root.manifests = root.parse(this.text);
                root.loaded = true;
                root.installEntries();
            }
        }
    }
}
