pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history on top of cliphist (which is fed by `wl-paste --watch cliphist store`).
// Pinned items are copied out of cliphist into our own folder, so they survive
// "clear all", cliphist's item limit, and the new id cliphist gives an item when it is re-copied.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/quickshell/clipboard"
    readonly property string pinDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/quickshell/clipboard"
    readonly property int previewWidth: 300

    // history: [{ id, line, preview, image, meta }] newest first
    property var history: []
    // pins: [{ key, preview, image, meta }] newest first
    property var pins: []
    // ids whose thumbnail file is ready in cacheDir
    property var thumbs: ({})
    property var thumbQueue: []
    property bool loaded: false

    // history without the items that are already pinned. A pin is matched by its
    // preview (the first 300 characters, or an image's size and dimensions).
    readonly property var unpinned: {
        if (pins.length === 0)
            return history;
        const seen = {};
        for (const p of pins)
            seen[p.preview] = true;
        return history.filter(e => !seen[e.preview]);
    }

    function thumbPath(id) {
        return "file://" + cacheDir + "/" + id;
    }

    function pinPath(key) {
        return pinDir + "/" + key;
    }

    // run a command, call back with (stdout, exitCode)
    function run(command, callback) {
        const p = procComponent.createObject(root, {
            "command": command
        });
        p.callback = callback || null;
        p.running = true;
    }

    function parse(line) {
        const tab = line.indexOf("\t");
        if (tab < 0)
            return null;
        const preview = line.substring(tab + 1);
        const m = preview.match(/^\[\[ binary data (.+) (png|jpe?g|bmp|gif|webp|tiff?|avif) (\d+x\d+) \]\]$/);
        return {
            "id": line.substring(0, tab),
            "line": line,
            "preview": preview,
            "image": !!m,
            "meta": m ? m[3].replace("x", " × ") + "  ·  " + m[1] : ""
        };
    }

    function refresh() {
        run(["cliphist", "-preview-width", String(previewWidth), "list"], text => {
            const items = [];
            for (const line of text.split("\n")) {
                const e = line ? parse(line) : null;
                if (e)
                    items.push(e);
            }
            root.history = items;
            root.loaded = true;
        });
    }

    // decode an image entry into the cache so the list can show it
    function requestThumb(id) {
        if (thumbs[id] || thumbQueue.indexOf(id) >= 0)
            return;
        thumbQueue.push(id);
        thumbTimer.restart();
    }

    function flushThumbs() {
        const ids = thumbQueue;
        thumbQueue = [];
        if (ids.length === 0)
            return;
        run(["sh", "-c", "d=$1; shift; mkdir -p \"$d\"; for id; do [ -s \"$d/$id\" ] || { cliphist decode \"$id\" > \"$d/$id.tmp\" && mv \"$d/$id.tmp\" \"$d/$id\"; }; done", "sh", cacheDir].concat(ids), () => {
            const t = Object.assign({}, root.thumbs);
            for (const id of ids)
                t[id] = true;
            root.thumbs = t;
        });
    }

    // Puts the item on the clipboard, then (optionally) pastes it into the window
    // that gets focus back once the menu has closed. Terminals paste with Ctrl+Shift+V.
    readonly property string pasteKeys: "sleep 0.15; case \"$(hyprctl activewindow | sed -n 's/^\\s*class: //p')\" in "
        + "*[Kk]itty*|*foot*|*[Aa]lacritty*|*ghostty*|*wezterm*|*[Kk]onsole*|*[Tt]erminal*|*[Tt]erminator*|*tilix*|*ptyxis*|*kgx*|*st-256color*)"
        + "wtype -M ctrl -M shift -k v -m shift -m ctrl ;; *) wtype -M ctrl -k v -m ctrl ;; esac"

    // the window that was focused when the menu opened ("0x..."); the paste goes there even when a
    // click on the menu has moved the focus somewhere else
    property string target: ""

    // $2 and $3 are the command that focuses that window (Lua form, then the old form), see HyprCommand
    readonly property string refocus: "if [ -n \"$2\" ]; then case \"$(hyprctl dispatch \"$2\" 2>&1)\" in ok*) ;; *) hyprctl dispatch \"$3\" >/dev/null 2>&1 ;; esac; fi; "

    function pasteCommand() {
        return (Config.clipboard?.autoPaste ?? true) ? refocus + pasteKeys : "true";
    }

    function focusArgs() {
        const a = HyprCommand.clean(target);
        return a === "" ? ["", ""] : ["hl.dsp.focus({ window = \"address:" + a + "\" })", "focuswindow address:" + a];
    }

    function paste(entry) {
        const f = focusArgs();
        if (entry.key !== undefined)
            Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\" && { " + pasteCommand() + "; }", "sh", pinPath(entry.key), f[0], f[1]]);
        else
            Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy && { " + pasteCommand() + "; }", "sh", entry.id, f[0], f[1]]);
    }

    // Same as paste, for plain text that is not an entry of the history (an emoji).
    function pasteText(text) {
        const f = focusArgs();
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy && { " + pasteCommand() + "; }", "sh", text, f[0], f[1]]);
    }

    function remove(entry) {
        if (entry.key !== undefined) {
            root.pins = pins.filter(p => p.key !== entry.key);
            run(["rm", "-f", pinPath(entry.key)], savePins);
            return;
        }
        root.history = history.filter(e => e.id !== entry.id);
        run(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete; rm -f \"$2\"", "sh", entry.line, cacheDir + "/" + entry.id]);
    }

    function togglePin(entry) {
        if (entry.key !== undefined) {
            // unpin: hand it back to the history so it is not lost
            root.pins = pins.filter(p => p.key !== entry.key);
            run(["sh", "-c", "cliphist store < \"$1\"; rm -f \"$1\"", "sh", pinPath(entry.key)], () => {
                savePins();
                refresh();
            });
            return;
        }
        const key = String(Date.now());
        run(["sh", "-c", "mkdir -p \"$2\" && cliphist decode \"$1\" > \"$2/$3\"", "sh", entry.id, pinDir, key], (text, code) => {
            if (code !== 0)
                return;
            root.pins = [{
                "key": key,
                "preview": entry.preview,
                "image": entry.image,
                "meta": entry.meta
            }].concat(root.pins);
            savePins();
        });
    }

    // clears the history; pinned items stay
    function wipe() {
        root.history = [];
        root.thumbs = ({});
        run(["sh", "-c", "cliphist wipe; rm -rf \"$1\"", "sh", cacheDir]);
    }

    function savePins() {
        run(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/pins.json\"", "sh", pinDir, JSON.stringify(pins)]);
    }

    Component.onCompleted: {
        run(["cat", pinDir + "/pins.json"], text => {
            try {
                const data = JSON.parse(text);
                if (Array.isArray(data))
                    root.pins = data.filter(p => p && p.key);
            } catch (e) {}
        });
        // drop thumbnails of entries cliphist no longer has
        Quickshell.execDetached(["sh", "-c", "cd \"$1\" 2>/dev/null || exit 0; cliphist list | cut -f1 | sort > .ids; ls | sort | comm -23 - .ids | xargs -r rm -f; rm -f .ids", "sh", cacheDir]);
        refresh();
    }

    Timer {
        id: thumbTimer

        interval: 20
        onTriggered: root.flushThumbs()
    }

    Component {
        id: procComponent

        Process {
            id: proc

            property var callback: null
            property int code: -1
            property bool exitedDone: false
            property bool streamDone: false

            // the exit and the end of stdout can arrive in either order
            function finish() {
                if (!exitedDone || !streamDone)
                    return;
                if (callback)
                    callback(out.text, code);
                destroy();
            }

            stdout: StdioCollector {
                id: out

                onStreamFinished: {
                    proc.streamDone = true;
                    proc.finish();
                }
            }

            onExited: exitCode => {
                proc.code = exitCode;
                proc.exitedDone = true;
                proc.finish();
            }
        }
    }
}
