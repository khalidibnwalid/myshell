pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The Paint document. The pixels live in the paint-engine helper (layers, selection, history, drawing);
// this singleton starts it, sends it commands and keeps what it reports (layers, history, selection, which
// tiles to show). It also holds the tool and its options, so they survive the window being closed.
Singleton {
    id: root

    readonly property string tileDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-paint"
    property bool ready: false
    property int docW: 0
    property int docH: 0
    property var layers: []
    property int activeId: 0
    property var hist: []
    property int hi: 0
    property var sel: null
    property var tileVer: ({})
    property string path: ""
    property int savedHi: 0
    property string status: ""
    property bool pendingTextEdit: false
    readonly property bool modified: hi !== savedHi
    readonly property var active: layers.find(l => l.id === activeId) ?? null
    readonly property bool activeIsText: active !== null && active.kind === "text"
    readonly property string docName: path === "" ? "Untitled" : path.split("/").pop()

    // tool and options
    property string tool: "brush"
    property color primary: "#000000"
    property color secondary: "#ffffff"
    property real brushSize: 20
    property real hardness: 0.75
    property real spacing: 0.15
    property real tolerance: 0.5
    property bool antialias: true
    property bool globalFill: false
    property string selMode: "replace"
    property string gradientMode: "linear"
    property string shapeKind: "rect"
    property string shapeFill: "outline"
    property real lineWidth: 4
    property real cornerRadius: 16
    property string pickSource: "layer"
    property string textFamily: "Sans Serif"
    property real textSize: 32
    property bool textBold: false
    property bool textItalic: false
    property bool textUnderline: false
    property string textAlign: "left"
    property var recents: []

    signal picked(string color)
    signal reset
    signal failed(string message)

    function hex8(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b) + h(c.a);
    }

    function fromHex8(s) {
        return Qt.rgba(parseInt(s.slice(1, 3), 16) / 255, parseInt(s.slice(3, 5), 16) / 255, parseInt(s.slice(5, 7), 16) / 255, parseInt(s.slice(7, 9), 16) / 255);
    }

    function say(message) {
        status = message;
        statusTimer.restart();
    }

    function send(cmd) {
        const line = JSON.stringify(cmd) + "\n";
        ensure();
        if (engineUp)
            engine.write(line);
        else
            queue.push(line);
    }

    function ensure() {
        if (!engine.running)
            engine.running = true;
    }

    function newDoc(w, h, background) {
        path = "";
        send({
            "op": "new",
            "w": w,
            "h": h,
            "mode": background === "transparent" ? "transparent" : "solid",
            "color": background === "primary" ? hex8(primary) : "#ffffffff"
        });
    }

    function start() {
        ensure();
        if (!requested) {
            requested = true;
            newDoc(1280, 720, "white");
        }
    }

    function openFile(file) {
        const p = String(file).replace(/^file:\/\//, "");
        send({
            "op": "open",
            "path": decodeURIComponent(p)
        });
    }

    function importFile(file) {
        send({
            "op": "import",
            "path": decodeURIComponent(String(file).replace(/^file:\/\//, ""))
        });
    }

    function saveTo(file, quality) {
        const p = decodeURIComponent(String(file).replace(/^file:\/\//, ""));
        pendingSave = p;
        send({
            "op": "save",
            "path": p,
            "quality": quality ?? 92
        });
    }

    property string pendingSave: ""
    property bool requested: false
    property bool engineUp: false
    property var queue: []

    function select(id) {
        activeId = id;
        send({
            "op": "layer",
            "kind": "select",
            "layer": id
        });
    }

    function layerOp(kind, id) {
        send({
            "op": "layer",
            "kind": kind,
            "layer": id ?? activeId
        });
    }

    function setLayer(id, fields, final) {
        send(Object.assign({
            "op": "layer",
            "kind": "set",
            "layer": id,
            "final": final !== false
        }, fields));
    }

    function addRecent(c) {
        const s = String(c);
        recents = [s].concat(recents.filter(x => x !== s)).slice(0, 12);
    }

    function textProps(text) {
        return {
            "text": text,
            "family": textFamily,
            "size": textSize,
            "bold": textBold,
            "italic": textItalic,
            "underline": textUnderline,
            "align": textAlign,
            "color": String(primary)
        };
    }

    function handle(ev) {
        switch (ev.ev) {
        case "reset":
            if (ev.w === 1 && ev.h === 1 && !requested)
                break;
            ready = true;
            docW = ev.w;
            docH = ev.h;
            tileVer = ({});
            savedHi = 0;
            sel = null;
            reset();
            break;
        case "tiles":
            {
                const next = Object.assign({}, tileVer);
                for (const t of ev.tiles)
                    next[t[0] + "_" + t[1]] = t[2];
                tileVer = next;
            }
            break;
        case "state":
            docW = ev.w;
            docH = ev.h;
            layers = ev.layers || [];
            activeId = ev.active;
            hist = ev.hist || [];
            hi = ev.hi;
            sel = ev.sel;
            if (pendingTextEdit && active && active.kind === "text") {
                pendingTextEdit = false;
                textEditRequested(active.id);
            }
            break;
        case "opened":
            path = ev.path;
            savedHi = hi;
            status = "Opened " + ev.path.split("/").pop();
            break;
        case "saved":
            if (/\.ora$/i.test(ev.path) || path === "")
                path = ev.path;
            savedHi = hi;
            status = "Saved " + ev.path.split("/").pop();
            break;
        case "pick":
            picked(ev.color);
            break;
        case "clip":
            clipProc.exec(["sh", "-c", "command -v wl-copy >/dev/null && wl-copy -t image/png < \"$1\"", "sh", ev.path]);
            break;
        case "error":
            status = ev.message;
            failed(ev.message);
            break;
        }
        if (status !== "")
            statusTimer.restart();
    }

    signal textEditRequested(int id)

    Timer {
        id: statusTimer

        interval: 4000
        onTriggered: root.status = ""
    }

    Process {
        id: clipProc

        stdout: StdioCollector {
        }
    }

    Process {
        id: engine

        command: ["sh", "-c", 'b=$("$1/helpers/paint-engine/build.sh" "$2") && exec setpriv --pdeathsig KILL "$b" -dir "$3"', "sh", Quickshell.shellDir, (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/paint", root.tileDir]
        stdinEnabled: true
        onStarted: {
            root.engineUp = true;
            for (const line of root.queue)
                write(line);
            root.queue = [];
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line));
                } catch (e) {
                    console.warn("paint-engine:", e, line.slice(0, 120));
                }
            }
        }
        onExited: {
            root.engineUp = false;
            root.ready = false;
            root.requested = false;
            root.docW = 0;
        }
    }
}
