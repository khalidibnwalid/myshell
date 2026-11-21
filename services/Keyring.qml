pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keyrings and the passwords in them, through the Secret Service (org.freedesktop.secrets:
// gnome-keyring here). The work is done by helpers/keyring, which waits for the keyring's own
// password prompts; secrets go from it straight to wl-copy and never through QML.
Singleton {
    id: root

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/keyring"
    // runs the helper with the given arguments ("$@")
    readonly property string runner: 'b=$("$0/helpers/keyring/build.sh" "$1") || exit 1; shift 2; exec "$b" "$@"'

    // [{ path, label, locked, default, created, modified, items: [{ path, label, locked, created, modified, attrs }] }]
    property var keyrings: []
    // a Secret Service answers
    property bool available: false
    property bool loaded: false
    // what the last action did, for the page's status line
    property string message: ""
    readonly property int clearAfter: 45

    // Names apps put in their keyring entries that differ from their desktop entries
    readonly property var aliases: ({
            "chrome": "google-chrome",
            "chromium": "chromium",
            "brave": "brave-browser",
            "microsoft edge": "microsoft-edge",
            "vivaldi": "vivaldi-stable",
            "code": "com.microsoft.VSCode",
            "networkmanager": "nm-connection-editor",
            "evolution": "org.gnome.Evolution",
            "geary": "org.gnome.Geary"
        })

    function lookup(name) {
        const key = (name || "").trim().toLowerCase();
        if (key === "")
            return null;
        const id = aliases[key] || key;
        return DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id) || (id !== key ? DesktopEntries.heuristicLookup(key) : null);
    }

    // The app that saved an item, for its icon: its "application" attribute, the app named in
    // the schema, or the browser in "<Browser> Safe Storage". Null when no app owns it.
    function appFor(item) {
        const a = item.attrs || {};
        const schema = a["xdg:schema"] || "";
        const candidates = [a.application, a.app_id];
        if (schema.indexOf("NetworkManager") !== -1)
            candidates.push("networkmanager");
        const named = schema.match(/^org\.(?:gnome|kde|freedesktop)\.([A-Za-z]+)/);
        if (named && ["Secret", "keyring", "Keyring"].indexOf(named[1]) === -1)
            candidates.push(named[1]);
        const storage = (item.label || "").match(/^(.+?) Safe Storage/);
        if (storage)
            candidates.push(storage[1]);
        for (const c of candidates) {
            const entry = lookup(c);
            if (entry)
                return entry;
        }
        return null;
    }

    function iconFor(item) {
        const entry = appFor(item);
        return entry && entry.icon ? Icons.path(entry.icon, true) : "";
    }

    function helper(args) {
        return ["sh", "-c", runner, Quickshell.shellDir, cacheDir, "--"].concat(args);
    }

    function refresh() {
        listProc.running = true;
    }

    // the session keyring is in memory only; it shows only when something is in it
    function shown() {
        return keyrings.filter(k => !k.path.endsWith("/collection/session") || k.items.length > 0);
    }

    function name(keyring) {
        if (keyring.path.endsWith("/collection/session"))
            return "Until you log out";
        return keyring.label || keyring.path.split("/").pop().replace(/_5f/g, "_").replace(/_/g, " ");
    }

    function run(args, done) {
        const p = actionComponent.createObject(root, {
            "command": helper(args),
            "done": done || ""
        });
        p.running = true;
    }

    function lock(path) {
        run(["lock", path]);
    }

    function unlock(path) {
        run(["unlock", path]);
    }

    function changePassword(path) {
        run(["password", path], "Password changed");
    }

    function create(label) {
        run(["create", label], "Keyring “" + label + "” made");
    }

    function setDefault(path) {
        run(["default", path]);
    }

    function remove(path, label) {
        run(["delete", path], "“" + label + "” deleted");
    }

    // copies the secret, then clears the clipboard after a while if it still holds it
    function copy(path, label) {
        message = "Copying “" + label + "”…";
        const p = actionComponent.createObject(root, {
            "command": ["sh", "-c", 'b=$("$0/helpers/keyring/build.sh" "$1") || exit 1; s=$("$b" secret "$2") || exit $?; printf %s "$s" | wl-copy --sensitive || exit 1; echo copied; sleep "$3"; [ "$(wl-paste -n 2>/dev/null)" = "$s" ] && wl-copy --clear; exit 0', Quickshell.shellDir, cacheDir, path, String(clearAfter)],
            "startedText": "Copied “" + label + "”. The clipboard is cleared in " + clearAfter + " seconds."
        });
        p.running = true;
    }

    function store(keyringPath, label, account, secret) {
        const p = actionComponent.createObject(root, {
            "command": helper(["store", keyringPath, label, account]),
            "done": "“" + label + "” saved",
            "input": secret
        });
        p.running = true;
    }

    function finished(code, err, done) {
        if (code === 0) {
            if (done)
                message = done;
        } else if (code === 2) {
            message = "Cancelled";
        } else {
            message = err.trim().split("\n").pop() || "That did not work";
        }
        refresh();
    }

    Component {
        id: actionComponent

        Process {
            id: proc

            property string done: ""
            property string input: ""
            // shown when the helper prints its first line
            property string startedText: ""

            stdinEnabled: input !== ""
            onStarted: {
                if (input !== "") {
                    write(input);
                    stdinEnabled = false;
                }
            }
            onExited: code => {
                root.finished(code, errors.text, done);
                destroy();
            }

            stdout: SplitParser {
                onRead: {
                    if (proc.startedText)
                        root.message = proc.startedText;
                }
            }

            stderr: StdioCollector {
                id: errors
            }
        }
    }

    Process {
        id: listProc

        command: root.helper(["list"])

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(text) {
        try {
            keyrings = JSON.parse(text);
            available = true;
        } catch (e) {
            keyrings = [];
            available = false;
        }
        loaded = true;
    }
}
