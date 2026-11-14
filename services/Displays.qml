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

    function logicalSize(m) {
        const t = Number((m.lastIpcObject || {}).transform || 0);
        const w = m.width / m.scale;
        const h = m.height / m.scale;
        return t % 2 === 1 ? { "w": h, "h": w } : { "w": w, "h": h };
    }

    // where a dragged display lands: against the nearest edge of another one, aligned when close
    function snap(monitor, x, y, monitors) {
        const me = logicalSize(monitor);
        const keep = 64;
        const near = 40;
        const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
        let best = null;
        for (const other of monitors) {
            if (other.name === monitor.name)
                continue;
            const o = logicalSize(other);
            const sideY = clamp(y, other.y - me.h + keep, other.y + o.h - keep);
            const sideX = clamp(x, other.x - me.w + keep, other.x + o.w - keep);
            const options = [
                { "x": other.x + o.w, "y": sideY },
                { "x": other.x - me.w, "y": sideY },
                { "x": sideX, "y": other.y + o.h },
                { "x": sideX, "y": other.y - me.h }
            ];
            for (const c of options) {
                if (Math.abs(c.y - other.y) < near)
                    c.y = other.y;
                else if (Math.abs(c.y + me.h - (other.y + o.h)) < near)
                    c.y = other.y + o.h - me.h;
                if (Math.abs(c.x - other.x) < near)
                    c.x = other.x;
                else if (Math.abs(c.x + me.w - (other.x + o.w)) < near)
                    c.x = other.x + o.w - me.w;
                const d = Math.hypot(c.x - x, c.y - y);
                if (!best || d < best.d)
                    best = { "x": Math.round(c.x), "y": Math.round(c.y), "d": d };
            }
        }
        return best || { "x": monitor.x, "y": monitor.y };
    }

    // place a display and remember it
    function move(monitor, x, y) {
        const mode = currentMode(monitor);
        const position = Math.round(x) + "x" + Math.round(y);
        send(monitor.name, mode, monitor.scale, position);
        const next = JSON.parse(JSON.stringify(saved));
        next[monitor.name] = Object.assign({}, next[monitor.name] || {}, {
            "mode": next[monitor.name]?.mode || mode,
            "scale": next[monitor.name]?.scale || monitor.scale,
            "position": position
        });
        Config.setMonitors(next);
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
        next[pending.name] = Object.assign({}, next[pending.name] || {}, pending.next);
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
                send(name, entry.mode, entry.scale, entry.position || "auto");
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
