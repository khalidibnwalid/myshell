import QtQuick
import Quickshell
import Quickshell.Io

// The sound engine of Audio: an `mpv` process without a window, driven over its JSON socket. It plays
// whatever FFmpeg can read, and its decoders stay out of the shell's own process.
Scope {
    id: root

    property string source: ""
    // linear volume 0..1 and the speed of playback
    property real gain: 1
    property real rate: 1

    // ms; the duration is 0 until the file has loaded
    property real position: 0
    property real duration: 0
    // "idle" | "loading" | "ready" (loaded, playing or paused) | "ended" | "stopped"
    property string status: "idle"
    property bool paused: true
    readonly property bool playing: status === "ready" && !paused

    // the end of the track, and a file that cannot be played
    signal ended
    signal failed(string message)

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-audio-mpv.sock"
    property bool wantPaused: true
    property real startMs: 0
    property int tries: 0
    property bool retryOn: false
    property var queued: []

    // loads a file; it plays from `from` ms, paused when `startPaused`
    function open(url, from, startPaused) {
        source = url;
        startMs = from || 0;
        wantPaused = startPaused !== false;
        position = startMs;
        duration = 0;
        status = "loading";
        paused = wantPaused;
        // a new load replaces whatever was waiting for mpv
        queued = [];
        let path = url;
        if (path.startsWith("file://"))
            path = decodeURIComponent(path.substring(7));
        send(["set_property", "pause", wantPaused]);
        send(["loadfile", path, "replace"]);
    }

    function play() {
        if (source === "")
            return;
        if (status !== "ready") {
            // after the end or a stop: from the start again
            open(source, 0, false);
            return;
        }
        paused = false;
        send(["set_property", "pause", false]);
    }

    function pause() {
        paused = true;
        if (status === "ready")
            send(["set_property", "pause", true]);
    }

    function stop() {
        if (status === "idle")
            return;
        status = "stopped";
        if (socket.connected)
            send(["stop"]);
    }

    function restart() {
        if (source !== "")
            open(source, 0, false);
    }

    function seek(ms) {
        position = ms;
        if (status === "ready")
            send(["seek", ms / 1000, "absolute"]);
        else
            startMs = ms;
    }

    function shutdown() {
        if (socket.connected)
            socket.write(JSON.stringify({
                "command": ["quit"]
            }) + "\n");
        proc.running = false;
    }

    function send(cmd, id) {
        const line = JSON.stringify(id ? {
            "command": cmd,
            "request_id": id
        } : {
            "command": cmd
        }) + "\n";
        // only a living mpv can be written to: a socket that still says "connected" after mpv died is not
        if (proc.running && socket.connected) {
            socket.write(line);
            socket.flush();
            return;
        }
        queued = queued.concat([line]);
        if (!proc.running)
            proc.running = true;
        else if (!connect.running) {
            // mpv is up but the socket is not: connect again
            tries = 0;
            connect.restart();
        }
    }

    function onLine(line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (m.request_id === 1 && m.error === "success" && typeof m.data === "number") {
            position = m.data * 1000;
        } else if (m.request_id === 2 && m.error === "success" && typeof m.data === "number") {
            duration = m.data * 1000;
        }
        switch (m.event) {
        case "file-loaded":
            status = "ready";
            if (startMs > 0)
                send(["seek", startMs / 1000, "absolute"]);
            startMs = 0;
            send(["get_property", "duration"], 2);
            break;
        case "end-file":
            if (m.reason === "eof") {
                status = "ended";
                paused = true;
                ended();
            } else if (m.reason === "error") {
                status = "stopped";
                paused = true;
                failed(m.file_error || "This file cannot be played");
            }
            break;
        case "property-change":
            if (m.name === "pause" && status === "ready" && typeof m.data === "boolean")
                paused = m.data;
            break;
        }
    }

    onGainChanged: applyGain()
    onRateChanged: {
        if (socket.connected)
            send(["set_property", "speed", rate]);
    }

    // the gain is set in dB, so that it is exactly the volume the player asks for
    function applyGain() {
        if (!socket.connected)
            return;
        send(["set_property", "volume-gain", gain <= 0.0001 ? -150 : 20 * Math.log(gain) / Math.LN10]);
    }

    // mpv has no event for the position: asked while it plays
    Timer {
        interval: 200
        repeat: true
        running: root.playing
        onTriggered: root.send(["get_property", "time-pos"], 1)
    }

    Timer {
        id: connect

        interval: 100
        repeat: true
        onTriggered: {
            if (socket.connected) {
                connect.stop();
                return;
            }
            // a first start after boot can be slow: wait up to 15 s
            if (root.tries++ > 150) {
                connect.stop();
                // end the mpv that never answered, so the next play starts a new one
                root.queued = [];
                proc.running = false;
                root.status = "stopped";
                root.paused = true;
                root.failed("mpv did not start");
                return;
            }
            // released on one tick and asked again on the next: a socket that is told "false" and "true" at once
            // keeps the refused first try and never connects again
            if (root.retryOn) {
                root.retryOn = false;
                socket.connected = true;
            } else {
                root.retryOn = true;
                socket.connected = false;
            }
        }
    }

    Socket {
        id: socket

        path: root.socketPath
        parser: SplitParser {
            onRead: line => root.onLine(line)
        }
        onConnectedChanged: {
            if (!connected)
                return;
            connect.stop();
            root.tries = 0;
            root.applyGain();
            root.send(["set_property", "speed", root.rate]);
            root.send(["observe_property", 3, "pause"]);
            const lines = root.queued;
            root.queued = [];
            for (const l of lines)
                write(l);
            flush();
        }
    }

    Process {
        id: proc

        // mpv dies with the shell, and with this wrapper when it is stopped or killed: a watcher ends it when either is gone (setpriv --pdeathsig
        // follows the thread that started mpv, which can end at any time and took mpv with it)
        command: ["sh", "-c", 'p=$PPID; s=$$; "$@" & m=$!; trap "kill $m" TERM INT HUP; (while kill -0 $p 2>/dev/null && kill -0 $s 2>/dev/null && kill -0 $m 2>/dev/null; do sleep 2; done; kill $m 2>/dev/null) >/dev/null 2>&1 & wait $m', "sh", "mpv", "--idle=yes", "--no-config", "--no-terminal", "--really-quiet", "--no-video", "--audio-display=no", "--force-window=no", "--no-osc", "--no-input-default-bindings", "--input-media-keys=no", "--load-scripts=no", "--ytdl=no", "--audio-client-name=Audio", "--input-ipc-server=" + root.socketPath]
        onRunningChanged: {
            if (running) {
                root.tries = 0;
                connect.restart();
            } else {
                connect.stop();
                // drop the socket of the mpv that ended, so nothing is written to it
                socket.connected = false;
                if (root.status !== "idle" && root.status !== "ended") {
                    root.status = "stopped";
                    root.paused = true;
                }
            }
        }
    }
}
