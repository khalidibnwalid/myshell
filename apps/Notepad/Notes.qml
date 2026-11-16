pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Notes kept in one JSON file: [{ id, text, pinned, updated }]. The title is the first line.
// Typing is saved a moment after the last key, so nothing is lost when the window closes.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/quickshell/notepad"
    readonly property string filePath: dir + "/notes.json"

    property var notes: []
    property string currentId: ""
    property bool loaded: false
    // a note asked for before the file was read is made as soon as it has been
    property bool createPending: false
    // a file asked for before the notes were read is opened as soon as they have been
    property string openPending: ""
    // what the last open or save did, shown for a moment
    property string status: ""
    readonly property var current: notes.find(n => n.id === currentId) ?? null

    // pinned notes first, then the rest, each group in the order the user dragged them to
    // (new notes start at the top)
    function sorted(query) {
        const q = (query || "").trim().toLowerCase();
        const list = notes.filter(n => q === "" || n.text.toLowerCase().includes(q));
        return list.filter(n => n.pinned).concat(list.filter(n => !n.pinned));
    }

    // the order a drag ended in (ids of every note shown)
    function reorder(ids) {
        const byId = {};
        for (const n of notes)
            byId[n.id] = n;
        const next = ids.map(id => byId[id]).filter(n => n !== undefined);
        notes = next.concat(notes.filter(n => ids.indexOf(n.id) < 0));
        save();
    }

    function titleOf(note) {
        const line = note.text.split("\n").find(l => l.trim() !== "");
        return line ? line.trim() : "New note";
    }

    function previewOf(note) {
        const lines = note.text.split("\n").filter(l => l.trim() !== "");
        return lines.length > 1 ? lines[1].trim() : "";
    }

    // a new note on top, selected; `text` and `path` for one that starts with content
    function create(text, path) {
        if (!loaded) {
            createPending = true;
            refresh();
            return "";
        }
        const note = {
            "id": Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            "text": text || "",
            "pinned": false,
            "path": path || "",
            "updated": Date.now()
        };
        notes = [note].concat(notes);
        currentId = note.id;
        save();
        return note.id;
    }

    function setText(id, text) {
        const note = notes.find(n => n.id === id);
        if (!note || note.text === text)
            return;
        note.text = text;
        note.updated = Date.now();
        // same array contents; announce the change without rebuilding every row
        notesChanged();
        saveTimer.restart();
    }

    function togglePin(id) {
        const note = notes.find(n => n.id === id);
        if (!note)
            return;
        note.pinned = !note.pinned;
        notesChanged();
        save();
    }

    function remove(id) {
        const list = sorted("");
        const at = list.findIndex(n => n.id === id);
        notes = notes.filter(n => n.id !== id);
        if (currentId === id) {
            const next = sorted("");
            currentId = next.length > 0 ? next[Math.min(at, next.length - 1)].id : "";
        }
        save();
    }

    function select(id) {
        // an empty note that was left is not worth keeping
        const old = current;
        currentId = id;
        if (old && old.id !== id && old.text.trim() === "")
            remove(old.id);
    }

    function baseName(path) {
        return String(path || "").split("/").pop();
    }

    function cleanPath(path) {
        let p = String(path || "");
        if (p.startsWith("file://"))
            p = decodeURIComponent(p.slice(7));
        return p;
    }

    function say(text) {
        status = text;
        statusTimer.restart();
    }

    // opens a text file as a note that remembers where it came from; a file that is
    // already open is just selected
    function openFile(path) {
        const file = cleanPath(path);
        if (file === "")
            return;
        if (!loaded) {
            openPending = file;
            refresh();
            return;
        }
        const have = notes.find(n => n.path === file);
        if (have) {
            select(have.id);
            return;
        }
        readProc.file = file;
        readProc.command = ["sh", "-c", "[ -r \"$1\" ] || { printf '\\001QS_FAIL\\001'; exit 1; }; head -c 2000000 -- \"$1\"", "sh", file];
        readProc.running = true;
    }

    // called when the file has been read
    function finishOpen(file, text) {
        if (text === "\u0001QS_FAIL\u0001") {
            say("Could not open " + baseName(file));
            return;
        }
        // made with its text, so the editor never shows it empty first
        create(text, file);
        save();
        say("Opened " + baseName(file));
    }

    // writes the note to the file it came from; false when it has none yet
    function saveFile(id) {
        const note = notes.find(n => n.id === id);
        if (!note || note.path === "")
            return false;
        writeProc.file = note.path;
        writeProc.text = note.text;
        writeProc.command = ["sh", "-c", "cat > \"$1\"", "sh", note.path];
        writeProc.stdinEnabled = true;
        writeProc.running = true;
        return true;
    }

    function saveTo(id, path) {
        const note = notes.find(n => n.id === id);
        if (!note)
            return;
        note.path = cleanPath(path);
        notesChanged();
        save();
        saveFile(id);
    }

    function save() {
        // never write before the file was read, or the saved notes would be replaced
        if (!loaded)
            return;
        saveTimer.stop();
        writer.setText(JSON.stringify(notes));
    }

    function refresh() {
        if (!loaded)
            loadProc.running = true;
    }

    Timer {
        id: saveTimer

        interval: 600
        onTriggered: root.save()
    }

    Process {
        id: loadProc

        command: ["sh", "-c", "mkdir -p \"$1\"; cat \"$1/notes.json\" 2>/dev/null", "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(this.text);
                } catch (e) {
                    list = [];
                    // a file that cannot be read is kept aside, not written over
                    if (this.text.trim() !== "")
                        Quickshell.execDetached(["cp", root.filePath, root.filePath + ".corrupt"]);
                }
                root.notes = list.filter(n => n && typeof n.text === "string").map(n => ({
                            "id": String(n.id),
                            "text": n.text,
                            "pinned": n.pinned === true,
                            "path": typeof n.path === "string" ? n.path : "",
                            "updated": Number(n.updated) || 0
                        }));
                root.loaded = true;
                const first = root.sorted("")[0];
                if (first && root.currentId === "")
                    root.currentId = first.id;
                if (root.createPending) {
                    root.createPending = false;
                    root.create();
                }
                if (root.openPending !== "") {
                    const file = root.openPending;
                    root.openPending = "";
                    root.openFile(file);
                }
            }
        }
    }

    Timer {
        id: statusTimer

        interval: 3500
        onTriggered: root.status = ""
    }

    Process {
        id: readProc

        property string file: ""

        stdout: StdioCollector {
            onStreamFinished: root.finishOpen(readProc.file, this.text)
        }
    }

    Process {
        id: writeProc

        property string file: ""
        property string text: ""

        // the text goes in through stdin: it may be longer than a command line allows
        onStarted: {
            write(text);
            stdinEnabled = false;
        }
        onExited: code => root.say(code === 0 ? "Saved to " + root.baseName(file) : "Could not save " + root.baseName(file))
    }

    FileView {
        id: writer

        path: root.filePath
        preload: false
        atomicWrites: true
        printErrors: false
    }
}
