pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Countdown timers and a stopwatch. A timer is an end time, so it keeps counting while the window
// is closed and across a restart of the shell; nothing polls: one timer is set for the next end.
Singleton {
    id: root

    // [{ id, label, seconds, state: "running" | "paused" | "done", endAt (ms), left (s, while paused) }]
    property var timers: []
    // the stopwatch: running from startedAt, with the seconds counted before; laps in seconds
    property var stopwatch: ({
            "running": false,
            "startedAt": 0,
            "elapsed": 0,
            "laps": []
        })
    // the clock the window shows; it only moves while the window is open
    property double now: Date.now()
    property bool watching: false
    property bool loaded: false
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/quickshell/timer"
    readonly property int runningCount: timers.filter(t => t.state === "running").length

    // "90" (minutes), "5:30", "1:02:03" or "1h 30m", "45s"
    function parseDuration(text) {
        const t = text.trim().toLowerCase();
        if (t === "")
            return 0;
        let total = 0;
        const unit = /(\d+(?:\.\d+)?)\s*([hms])/g;
        let m;
        let found = false;
        while ((m = unit.exec(t)) !== null) {
            found = true;
            total += parseFloat(m[1]) * (m[2] === "h" ? 3600 : (m[2] === "m" ? 60 : 1));
        }
        if (found)
            return Math.round(total);
        if (/^\d+(:\d{1,2}){1,2}$/.test(t)) {
            const p = t.split(":").map(x => parseInt(x));
            return p.length === 2 ? p[0] * 60 + p[1] : p[0] * 3600 + p[1] * 60 + p[2];
        }
        if (/^\d+(\.\d+)?$/.test(t))
            return Math.round(parseFloat(t) * 60);
        return 0;
    }

    function format(seconds, tenths) {
        const s = Math.max(0, seconds);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = Math.floor(s % 60);
        const pad = n => String(n).padStart(2, "0");
        const base = (h > 0 ? h + ":" + pad(m) : m) + ":" + pad(sec);
        return tenths ? base + "." + Math.floor((s * 10) % 10) : base;
    }

    function left(t) {
        if (t.state === "running")
            return Math.max(0, (t.endAt - root.now) / 1000);
        if (t.state === "paused")
            return t.left;
        return 0;
    }

    function add(seconds, label) {
        if (!(seconds > 0))
            return;
        const t = {
            "id": Date.now() + "-" + Math.floor(Math.random() * 1000),
            "label": label || "",
            "seconds": seconds,
            "state": "running",
            "endAt": Date.now() + seconds * 1000,
            "left": seconds
        };
        root.timers = [t].concat(timers);
        changed();
    }

    function update(id, fields) {
        root.timers = timers.map(t => t.id === id ? Object.assign({}, t, fields) : t);
        changed();
    }

    function pause(id) {
        const t = timers.find(t => t.id === id);
        if (t && t.state === "running")
            update(id, {
                "state": "paused",
                "left": Math.max(0, (t.endAt - Date.now()) / 1000)
            });
    }

    function resume(id) {
        const t = timers.find(t => t.id === id);
        if (t && t.state === "paused")
            update(id, {
                "state": "running",
                "endAt": Date.now() + t.left * 1000
            });
    }

    function restart(id) {
        const t = timers.find(t => t.id === id);
        if (t)
            update(id, {
                "state": "running",
                "endAt": Date.now() + t.seconds * 1000,
                "left": t.seconds
            });
    }

    function remove(id) {
        root.timers = timers.filter(t => t.id !== id);
        changed();
    }

    function clearDone() {
        root.timers = timers.filter(t => t.state !== "done");
        changed();
    }

    function swElapsed() {
        return stopwatch.elapsed + (stopwatch.running ? (root.now - stopwatch.startedAt) / 1000 : 0);
    }

    function swToggle() {
        const sw = stopwatch;
        if (sw.running)
            root.stopwatch = {
                "running": false,
                "startedAt": 0,
                "elapsed": sw.elapsed + (Date.now() - sw.startedAt) / 1000,
                "laps": sw.laps
            };
        else
            root.stopwatch = {
                "running": true,
                "startedAt": Date.now(),
                "elapsed": sw.elapsed,
                "laps": sw.laps
            };
        root.now = Date.now();
        save();
    }

    function swLap() {
        if (!stopwatch.running)
            return;
        root.now = Date.now();
        root.stopwatch = Object.assign({}, stopwatch, {
            "laps": [swElapsed()].concat(stopwatch.laps)
        });
        save();
    }

    function swReset() {
        root.stopwatch = {
            "running": false,
            "startedAt": 0,
            "elapsed": 0,
            "laps": []
        };
        save();
    }

    function changed() {
        root.now = Date.now();
        schedule();
        save();
    }

    // one timer for the soonest end of a running countdown
    function schedule() {
        const ends = timers.filter(t => t.state === "running").map(t => t.endAt);
        if (ends.length === 0) {
            finishTimer.stop();
            return;
        }
        finishTimer.interval = Math.max(50, Math.min(Math.min.apply(null, ends) - Date.now(), 2000000000));
        finishTimer.restart();
    }

    // the app is switched off: nothing rings until it is switched on again
    function stop() {
        finishTimer.stop();
    }

    function finishDue() {
        const due = timers.filter(t => t.state === "running" && t.endAt <= Date.now() + 50);
        if (due.length === 0) {
            schedule();
            return;
        }
        root.timers = timers.map(t => due.indexOf(t) >= 0 ? Object.assign({}, t, {
                    "state": "done",
                    "left": 0
                }) : t);
        for (const t of due)
            ring(t);
        changed();
    }

    // a notification and a sound; the texts are arguments of the command, not part of it
    function ring(t) {
        const title = t.label !== "" ? t.label : "Timer";
        Quickshell.execDetached(["sh", "-c", "notify-send -a Timer -u critical -i alarm-symbolic \"$1\" \"$2\"; "
            + "{ canberra-gtk-play -i alarm-clock-elapsed 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null; } ", "sh", title + " is done", format(t.seconds) + " has passed"]);
    }

    function save() {
        file.setText(JSON.stringify({
            "timers": timers,
            "stopwatch": stopwatch
        }));
    }

    function load(text) {
        try {
            const d = JSON.parse(text);
            if (Array.isArray(d.timers))
                root.timers = d.timers;
            if (d.stopwatch)
                root.stopwatch = d.stopwatch;
        } catch (e) {
            return;
        }
        // timers that ended while the shell was not running
        const missed = timers.filter(t => t.state === "running" && t.endAt <= Date.now());
        if (missed.length > 0) {
            root.timers = timers.map(t => missed.indexOf(t) >= 0 ? Object.assign({}, t, {
                        "state": "done",
                        "left": 0
                    }) : t);
            for (const t of missed)
                ring(t);
            save();
        }
        root.loaded = true;
        schedule();
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dataDir])

    FileView {
        id: file

        path: root.dataDir + "/timers.json"
        atomicWrites: true
        onLoaded: root.load(text())
    }

    Timer {
        id: finishTimer

        onTriggered: root.finishDue()
    }

    Timer {
        interval: 100
        repeat: true
        running: root.watching && (root.runningCount > 0 || root.stopwatch.running)
        onTriggered: root.now = Date.now()
    }
}
