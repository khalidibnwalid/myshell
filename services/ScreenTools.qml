pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Io

// Small screen utilities: colour picker (hyprpicker), region screenshot (slurp + grim)
// and region screen recording (slurp + wl-screenrec, or wf-recorder when that is not installed).
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
    // what the area selection will do: "screenshot", "text" (extract the text in it), "qr" (read a QR code) or "video"
    property string captureMode: "screenshot"
    // true while the area is being selected; shows the option bar
    readonly property bool selecting: shotProc.running
    readonly property string modeFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-capture-mode"
    property bool stopRequested: false
    readonly property string elapsedText: Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0")
    // the image open in the screenshot editor ("" = closed). A shot from the cache folder belongs to the editor
    // and is removed when it closes; any other file is left alone
    property string editorPath: ""
    // the editor's tool, colour and size, kept while the shell runs
    property string editorTool: "arrow"
    property color editorColor: "#ff4d4d"
    property int editorSize: 1

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

    // from the selector's option bar: cancel the area selection, then pick a colour
    function pickColorFromSelector() {
        Quickshell.execDetached(["sh", "-c", "pkill -x slurp; sleep 0.3; c=$(hyprpicker -a) && [ -n \"$c\" ] && notify-send -a 'Color picker' \"$c\" 'Copied to the clipboard'"]);
    }

    // Copies the selected area. With Config.capture.autoSave it is also saved as a file;
    // without it, clicking the notification saves it.
    // $1 = screenshot folder, $2 = cache folder for shots that are not saved yet
    // $4 = file holding the chosen mode (screenshot or text), $5 = tesseract languages, $6 = 1 to open the editor at once
    readonly property string shotScript: "m=$(cat \"$4\" 2>/dev/null); "
        // Video: free the screen and hand the area back to the shell, which starts the recorder
        + "if [ \"$m\" = video ]; then kill $hp 2>/dev/null; rr; printf 'VIDEO %s' \"$g\"; exit; fi; "
        + "t=\"$2/$(date +%Y-%m-%d_%H-%M-%S).png\"; f=\"$1/Screenshot_$(basename \"$t\")\"; "
        + "mkdir -p \"$2\" && grim -g \"$g\" \"$t\" || exit 1; "
        // the frozen screen can go as soon as the shot is taken; the focus goes back to the window that had it,
        // unless the editor is about to open and take it
        + "kill $hp 2>/dev/null; if [ \"$6\" = 1 ] && [ \"${m:-screenshot}\" = screenshot ]; then trap - EXIT; else rr; fi; "
        // Extract text: read the area, copy the words, keep no picture
        + "if [ \"$m\" = text ]; then "
        + "x=$(tesseract \"$t\" stdout -l \"$5\" 2>/dev/null | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}'); rm -f \"$t\"; "
        + "if [ -z \"$x\" ]; then notify-send -a Screenshot 'No text found' 'Try a larger area, or add a language in Settings'; "
        + "else printf %s \"$x\" | wl-copy; notify-send -a Screenshot 'Text copied' \"$(printf %s \"$x\" | head -c 160)\"; fi; exit; fi; "
        // QR code: read it, copy what it says; a web address can be opened from the notification
        + "if [ \"$m\" = qr ]; then "
        + "x=$(zbarimg -q --raw \"$t\" 2>/dev/null); rm -f \"$t\"; "
        + "if [ -z \"$x\" ]; then notify-send -a Screenshot 'No QR code found' 'Select the code with a little space around it'; exit; fi; "
        + "printf %s \"$x\" | wl-copy; "
        + "case \"$x\" in http://*|https://*) ( a=$(notify-send -a Screenshot -A default=Open 'QR code copied' \"$x\"); [ \"$a\" = default ] && xdg-open \"$x\" ) >/dev/null 2>&1 & ;; "
        + "*) notify-send -a Screenshot 'QR code copied' \"$(printf %s \"$x\" | head -c 160)\" ;; esac; exit; fi; "
        + "wl-copy -t image/png < \"$t\"; "
        + "save() { mkdir -p \"$1\" && mv \"$t\" \"$f\"; }; "
        // the saved notification offers the editor too; the file is the user's, so the editor keeps it
        + "saved() { a=$(notify-send -a Screenshot -i \"$f\" -A edit=Edit 'Screenshot saved' \"$f\"); [ \"$a\" = edit ] && qs ipc call capture edit \"$f\"; }; "
        // $6 = 1: the editor opens at once instead of the notification (the shell reads EDIT from the output)
        + "if [ \"$6\" = 1 ]; then if [ \"$3\" = save ] && save \"$1\"; then t=\"$f\"; notify-send -a Screenshot -i \"$f\" 'Screenshot saved' \"$f\"; fi; printf 'EDIT %s' \"$t\"; exit; fi; "
        // the rest waits for the notification to be clicked ("default"), its Edit button or a dismissal, so it runs
        // on its own with its output closed: the selector is finished as soon as the shot is taken.
        // Edit hands the file to the editor, which removes it when it closes
        + "( if [ \"$3\" = save ]; then save \"$1\" && saved; else "
        + "a=$(notify-send -a Screenshot -i \"$t\" -A default=Save -A edit=Edit 'Screenshot copied' 'Click to save it as a file'); "
        + "if [ \"$a\" = default ]; then save \"$1\" && saved; elif [ \"$a\" = edit ]; then qs ipc call capture edit \"$t\"; else rm -f \"$t\"; fi; fi ) >/dev/null 2>&1 &"

    // opens the screenshot editor with an image (from the notification's Edit button, the IPC or the setting)
    function editImage(path) {
        path = expand(String(path).replace(/^file:\/\//, ""));
        if (path === "")
            return;
        if (editorPath !== "" && editorPath !== path)
            dropShot(editorPath);
        editorPath = path;
    }

    function closeEditor() {
        dropShot(editorPath);
        editorPath = "";
    }

    // removes a shot that only the editor still holds
    function dropShot(path) {
        if (path.startsWith(cacheDir + "/"))
            Quickshell.execDetached(["rm", "-f", "--", path]);
    }

    function setMode(mode) {
        captureMode = mode;
        Quickshell.execDetached(["sh", "-c", "printf %s \"$2\" > \"$1\"", "sh", modeFile, mode]);
    }

    function screenshot(mode) {
        // hyprpicker holds a frozen copy of the screen while the area is selected, so menus,
        // tooltips and hover states that would vanish when focus moves stay in the shot
        // the window that had the focus is given it back afterwards (Lua dispatch, with the old name as a fallback): the selection runs on the screen that is
        // clicked, and with follow_mouse 2 the keyboard would stay there until a click on the other screen
        const script = "w=$(hyprctl activewindow -j 2>/dev/null | sed -n 's/.*\"address\": *\"\\([^\"]*\\)\".*/\\1/p' | head -n1); "
            + "r() { [ -n \"$w\" ] || return; hyprctl dispatch \"hl.dsp.focus({window=\\\"address:$w\\\"})\" >/dev/null 2>&1; hyprctl dispatch focuswindow \"address:$w\" >/dev/null 2>&1; }; "
            // the overlays go away a moment after their processes end, and the keyboard is only given back
            // once they have: so the focus is returned a little later, in the background, twice
            + "rr() { ( sleep 0.25; r; sleep 0.6; r ) >/dev/null 2>&1 & }; "
            + "hyprpicker -r -z >/dev/null 2>&1 & hp=$!; trap 'kill $hp 2>/dev/null; rr' EXIT; sleep 0.2; g=$(" + slurpCmd + ") || exit 0; " + shotScript;
        if (shotProc.running)
            return;
        setMode(mode || "screenshot");
        shotProc.command = ["sh", "-c", script, "sh", expand(Config.capture.screenshotDir), cacheDir, Config.capture.autoSave ? "save" : "ask", modeFile, Config.capture.ocrLanguages || "eng", Config.capture.openEditor ? "1" : ""];
        afterPanels(() => shotProc.running = true);
    }

    function extractText() {
        screenshot("text");
    }

    function toggleRecording() {
        if (recording)
            stopRecording();
        else if (!selectProc.running && !shotProc.running)
            afterPanels(() => selectProc.running = true);
    }

    function stopRecording() {
        if (!recording)
            return;
        // SIGINT lets the recorder finish the file properly
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
        // wl-screenrec when it is installed (hardware encoding), wf-recorder otherwise; $4 is set when sound is wanted
        recProc.command = ["sh", "-c", "mkdir -p \"$1\" && if command -v wl-screenrec >/dev/null; then exec wl-screenrec -g \"$2\" -f \"$3\" ${4:+--audio}; else exec wf-recorder -g \"$2\" -f \"$3\" ${4:+-a}; fi", "sh", dir, m[0], recordingFile, Config.capture.recordAudio ? "1" : ""];
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
        id: shotProc

        stdout: StdioCollector {
            onStreamFinished: {
                // the script prints the area only when the chosen action is a recording
                if (this.text.startsWith("VIDEO "))
                    root.startRecording(this.text.substring(6).trim());
                // or the shot, when the editor opens right after it
                else if (this.text.startsWith("EDIT "))
                    root.editImage(this.text.substring(5).trim());
            }
        }
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
                Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "Recording failed", "The recorder exited with code " + exitCode]);
        }
    }
}
