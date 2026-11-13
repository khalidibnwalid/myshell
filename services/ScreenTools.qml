pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Io

// Small screen utilities: colour picker (hyprpicker), region screenshot (slurp + grim)
// and region screen recording (slurp + wl-screenrec).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/quickshell/screenshots"
    // true from the moment the recorder starts until its file is written
    readonly property bool recording: recProc.running
    // recorded area in global layout coordinates, for the highlight frame
    property rect region: Qt.rect(0, 0, 0, 0)
    property int elapsed: 0
    property string recordingFile: ""
    property bool stopRequested: false
    readonly property string elapsedText: Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0")

    // area selection: dims the screen and outlines the selection in the accent colour.
    // stdin is closed because slurp waits on a piped stdin for a list of boxes before it shows up
    readonly property string slurpCmd: "slurp -d -w 2 -b '#00000066' -c '" + hex(Appearance.accentColor) + "' -s '#ffffff14' </dev/null"

    function hex(c) {
        return c.toString().substring(0, 7) + "ff";
    }

    function expand(path) {
        return path.startsWith("~") ? home + path.substring(1) : path;
    }

    // Runs `action` once the panel that triggered it has left the screen,
    // so it is neither in the shot nor in the way of the selection.
    function afterPanels(action) {
        if (WindowManager.quickSettingsVisible) {
            WindowManager.quickSettingsVisible = false;
            delay.action = action;
            delay.restart();
        } else {
            action();
        }
    }

    // picks a pixel colour and copies its hex code
    function pickColor() {
        afterPanels(() => Quickshell.execDetached(["sh", "-c", "c=$(hyprpicker -a) && [ -n \"$c\" ] && notify-send -a 'Color picker' \"$c\" 'Copied to the clipboard'"]));
    }

    // Copies the selected area. With Config.capture.autoSave it is also saved as a file;
    // without it, clicking the notification saves it.
    // $1 = screenshot folder, $2 = cache folder for shots that are not saved yet
    readonly property string shotScript: "t=\"$2/$(date +%Y-%m-%d_%H-%M-%S).png\"; f=\"$1/Screenshot_$(basename \"$t\")\"; "
        + "mkdir -p \"$2\" && grim -g \"$g\" \"$t\" || exit 1; "
        // the frozen screen can go as soon as the shot is taken
        + "kill $hp 2>/dev/null; wl-copy -t image/png < \"$t\"; "
        + "save() { mkdir -p \"$1\" && mv \"$t\" \"$f\" && notify-send -a Screenshot -i \"$f\" 'Screenshot saved' \"$f\"; }; "
        + "if [ \"$3\" = save ]; then save \"$1\"; exit; fi; "
        // waits until the notification is clicked ("default") or dismissed
        + "a=$(notify-send -a Screenshot -i \"$t\" -A default=Save 'Screenshot copied' 'Click to save it as a file'); "
        + "if [ \"$a\" = default ]; then save \"$1\"; else rm -f \"$t\"; fi"

    function screenshot() {
        // hyprpicker holds a frozen copy of the screen while the area is selected, so menus,
        // tooltips and hover states that would vanish when focus moves stay in the shot
        const script = "hyprpicker -r -z >/dev/null 2>&1 & hp=$!; trap 'kill $hp 2>/dev/null' EXIT; sleep 0.2; g=$(" + slurpCmd + ") || exit 0; " + shotScript;
        afterPanels(() => Quickshell.execDetached(["sh", "-c", script, "sh", expand(Config.capture.screenshotDir), cacheDir, Config.capture.autoSave ? "save" : "ask"]));
    }

    function toggleRecording() {
        if (recording)
            stopRecording();
        else if (!selectProc.running)
            afterPanels(() => selectProc.running = true);
    }

    function stopRecording() {
        if (!recording)
            return;
        // SIGINT lets wl-screenrec finish the file properly
        stopRequested = true;
        recProc.signal(2);
    }

    function startRecording(geometry) {
        const m = geometry.match(/(-?\d+),(-?\d+) (\d+)x(\d+)/);
        if (!m)
            return;
        region = Qt.rect(parseInt(m[1]), parseInt(m[2]), parseInt(m[3]), parseInt(m[4]));
        const dir = expand(Config.capture.recordingDir);
        recordingFile = dir + "/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        elapsed = 0;
        stopRequested = false;
        recProc.command = ["sh", "-c", "mkdir -p \"$1\" && exec wl-screenrec -g \"$2\" -f \"$3\" $4", "sh", dir, m[0], recordingFile, Config.capture.recordAudio ? "--audio" : ""];
        recProc.running = true;
    }

    Timer {
        id: delay

        property var action: null

        interval: 260
        onTriggered: {
            if (action)
                action();
            action = null;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed++
    }

    Process {
        id: selectProc

        command: ["sh", "-c", root.slurpCmd]

        stdout: StdioCollector {
            onStreamFinished: root.startRecording(this.text.trim())
        }
    }

    Process {
        id: recProc

        onExited: exitCode => {
            if (exitCode === 0 || root.stopRequested)
                Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "Recording saved", root.recordingFile]);
            else
                Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "Recording failed", "wl-screenrec exited with code " + exitCode]);
        }
    }
}
