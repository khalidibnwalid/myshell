pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Monitor mode and scale. A change is applied through `hyprctl keyword monitor`,
// kept only after it is confirmed, and then re-applied whenever the shell starts.
Singleton {
    id: root

    // change waiting for "Keep": { name, previous: { mode, scale } }
    property var pending: null
    property int secondsLeft: 0
    readonly property var saved: Config.monitors || ({})

    // "3072x1920@120.00Hz" for a HyprlandMonitor
    function currentMode(monitor) {
        const info = monitor.lastIpcObject || {};
        return monitor.width + "x" + monitor.height + "@" + Number(info.refreshRate || 60).toFixed(2) + "Hz";
    }

    function modes(monitor) {
        const list = (monitor.lastIpcObject || {}).availableModes || [];
        const current = currentMode(monitor);
        return list.indexOf(current) >= 0 ? list : [current].concat(list);
    }

    function modeLabel(mode) {
        const m = String(mode).match(/^(\d+)x(\d+)@([\d.]+)/);
        return m ? m[1] + " × " + m[2] + "  ·  " + Math.round(Number(m[3])) + " Hz" : String(mode);
    }

    // scales that give whole logical pixels at this resolution, plus the current one
    function scales(mode, current) {
        const m = String(mode).match(/^(\d+)x(\d+)/);
        const candidates = [1, 1.2, 1.25, 1.5, 1.6, 1.75, 2, 2.4, 2.5, 3];
        const whole = v => Math.abs(v - Math.round(v)) < 0.001;
        const fits = candidates.filter(s => !m || (whole(Number(m[1]) / s) && whole(Number(m[2]) / s)));
        if (fits.indexOf(current) < 0)
            fits.push(current);
        return fits.sort((a, b) => a - b);
    }

    function send(name, mode, scale, position) {
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", name + "," + String(mode).replace("Hz", "") + "," + position + "," + scale]);
        refreshTimer.restart();
    }

    // try a change; it is reverted unless keep() is called in time
    function change(monitor, mode, scale) {
        if (pending && pending.name !== monitor.name)
            revert();
        if (!pending)
            pending = {
                "name": monitor.name,
                "position": monitor.x + "x" + monitor.y,
                "previous": {
                    "mode": currentMode(monitor),
                    "scale": monitor.scale
                },
                "next": null
            };
        pending.next = {
            "mode": mode,
            "scale": scale
        };
        send(monitor.name, mode, scale, pending.position);
        secondsLeft = 15;
        countdown.restart();
    }

    function keep() {
        if (!pending)
            return;
        const next = JSON.parse(JSON.stringify(saved));
        next[pending.name] = pending.next;
        Config.setMonitors(next);
        pending = null;
        countdown.stop();
    }

    function revert() {
        if (!pending)
            return;
        send(pending.name, pending.previous.mode, pending.previous.scale, pending.position);
        pending = null;
        countdown.stop();
    }

    function isSaved(name) {
        return saved[name] !== undefined;
    }

    // forget the saved choice and go back to what the Hyprland config says
    function forget(name) {
        const next = JSON.parse(JSON.stringify(saved));
        delete next[name];
        Config.setMonitors(next);
        Quickshell.execDetached(["hyprctl", "reload"]);
        refreshTimer.restart();
    }

    function applySaved() {
        for (const name of Object.keys(saved)) {
            const entry = saved[name];
            if (entry && entry.mode && entry.scale)
                send(name, entry.mode, entry.scale, "auto");
        }
    }

    Timer {
        id: countdown

        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsLeft--;
            if (root.secondsLeft <= 0)
                root.revert();
        }
    }

    Timer {
        id: refreshTimer

        interval: 700
        onTriggered: Hyprland.refreshMonitors()
    }

    // once the config file has been read
    Timer {
        interval: 1200
        running: true
        onTriggered: root.applySaved()
    }
}
