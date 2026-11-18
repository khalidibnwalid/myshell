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
        if (socket.connected) {
            socket.write(line);
            socket.flush();
            return;
        }
        queued = queued.concat([line]);
        if (!proc.running)
            proc.running = true;
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
            if (root.tries++ > 50) {
                connect.stop();
                root.failed("mpv did not start");
                return;
            }
            socket.connected = false;
            socket.connected = true;
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

        // mpv dies with the shell: setpriv asks the kernel to end it with its parent
        command: ["sh", "-c", 'if command -v setpriv >/dev/null 2>&1; then exec setpriv --pdeathsig KILL "$@"; fi; exec "$@"', "sh", "mpv", "--idle=yes", "--no-config", "--no-terminal", "--really-quiet", "--no-video", "--audio-display=no", "--force-window=no", "--no-osc", "--no-input-default-bindings", "--input-media-keys=no", "--load-scripts=no", "--ytdl=no", "--audio-client-name=Audio", "--input-ipc-server=" + root.socketPath]
        onRunningChanged: {
            if (running) {
                root.tries = 0;
                connect.restart();
            } else {
                connect.stop();
                if (root.status !== "idle" && root.status !== "ended") {
                    root.status = "stopped";
                    root.paused = true;
                }
            }
        }
    }
}
