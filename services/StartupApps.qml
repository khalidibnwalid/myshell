pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Apps that start with the session, the XDG way: .desktop files in ~/.config/autostart and
// the system's /etc/xdg/autostart. This session runs under uwsm, which starts them. An entry
// of the system is switched off by a file of the same name in ~/.config/autostart with
// Hidden=true, as the XDG autostart specification says. Also lists what Hyprland itself starts
// (exec-once in its config), which is only shown, not changed.
Singleton {
    id: root

    readonly property string userDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/autostart"
    readonly property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland"

    // [{ file, name, comment, exec, icon, enabled, user, override }]
    property var apps: []
    // what Hyprland starts: [{ command, file }]
    property var hyprland: []
    property bool loaded: false

    function refresh() {
        listProc.running = true;
        hyprProc.running = true;
    }

    // a slug for a file name
    function slug(text) {
        return text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "app";
    }

    function run(command) {
        actionProc.command = ["sh", "-c", command.script, "sh"].concat(command.args);
        actionProc.running = true;
    }

    // switch an entry on or off
    function setEnabled(app, on) {
        const file = userDir + "/" + app.file;
        if (on) {
            // drop our override of a system entry; a user's own entry just gets Hidden=false
            run({
                "script": "f=\"$1\"; if grep -q '^X-Quickshell-Override=true' \"$f\" 2>/dev/null; then rm -f \"$f\"; else sed -i 's/^Hidden=true/Hidden=false/' \"$f\"; fi",
                "args": [file]
            });
        } else if (app.user) {
            run({
                "script": "f=\"$1\"; if grep -q '^Hidden=' \"$f\"; then sed -i 's/^Hidden=.*/Hidden=true/' \"$f\"; else printf 'Hidden=true\\n' >> \"$f\"; fi",
                "args": [file]
            });
        } else {
            run({
                "script": "mkdir -p \"$(dirname \"$1\")\" && printf '[Desktop Entry]\\nType=Application\\nName=%s\\nHidden=true\\nX-Quickshell-Override=true\\n' \"$2\" > \"$1\"",
                "args": [file, app.name]
            });
        }
        refreshTimer.restart();
    }

    // remove an entry made by the user
    function remove(app) {
        run({
            "script": "rm -f \"$1\"",
            "args": [userDir + "/" + app.file]
        });
        refreshTimer.restart();
    }

    // add a program: its desktop file is written to ~/.config/autostart
    function add(name, exec, icon) {
        if (name.trim() === "" || exec.trim() === "")
            return;
        const file = userDir + "/qs-" + slug(name) + ".desktop";
        run({
            "script": "mkdir -p \"$(dirname \"$1\")\" && printf '[Desktop Entry]\\nType=Application\\nName=%s\\nExec=%s\\nIcon=%s\\nX-GNOME-Autostart-enabled=true\\n' \"$2\" \"$3\" \"$4\" > \"$1\"",
            "args": [file, name.trim(), exec.trim(), icon || ""]
        });
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer

        interval: 600
        onTriggered: root.refresh()
    }

    Process {
        id: actionProc
    }

    // the user's folder and the system's (XDG_CONFIG_DIRS); the user's file wins by name
    Process {
        id: listProc

        command: ["sh", "-c", "scan() { for f in \"$1\"/*.desktop; do [ -f \"$f\" ] && { echo \"FILE=$f\"; cat \"$f\"; echo; }; done; }; scan \"${XDG_CONFIG_HOME:-$HOME/.config}/autostart\"; IFS=:; for c in ${XDG_CONFIG_DIRS:-/etc/xdg}; do scan \"$c/autostart\"; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const out = [];
                const blocks = text.split(/^FILE=/m).slice(1);
                for (const block of blocks) {
                    const lines = block.split(/\r?\n/);
                    const path = lines[0].trim();
                    const f = {};
                    let inEntry = false;
                    for (const l of lines.slice(1)) {
                        if (l.startsWith("[")) {
                            inEntry = l.trim() === "[Desktop Entry]";
                            continue;
                        }
                        const at = l.indexOf("=");
                        if (inEntry && at > 0 && !/^(Name|Comment)\[/.test(l))
                            f[l.slice(0, at).trim()] = l.slice(at + 1).trim();
                    }
                    const file = path.split("/").pop();
                    const user = path.startsWith(root.userDir + "/");
                    const entry = {
                        "file": file,
                        "name": f.Name || file.replace(/\.desktop$/, ""),
                        "comment": f.Comment || "",
                        "exec": f.Exec || "",
                        "icon": f.Icon || "",
                        "hidden": f.Hidden === "true" || f["X-GNOME-Autostart-enabled"] === "false",
                        "only": f.OnlyShowIn ? f.OnlyShowIn.split(";").filter(x => x) : [],
                        "not": f.NotShowIn ? f.NotShowIn.split(";").filter(x => x) : [],
                        "user": user,
                        "override": f["X-Quickshell-Override"] === "true"
                    };
                    // the user's file of the same name wins over the system's (it is read first);
                    // a bare override of ours takes the details from the system's entry
                    if (seen[file]) {
                        const first = seen[file];
                        if (first.override)
                            Object.assign(first, {
                                "name": entry.name,
                                "comment": entry.comment,
                                "exec": entry.exec,
                                "icon": entry.icon,
                                "only": entry.only,
                                "not": entry.not
                            });
                        continue;
                    }
                    seen[file] = entry;
                    out.push(entry);
                }
                const here = root.desktop.split(":");
                // entries meant for other desktops never start here, so they are left out
                const relevant = out.filter(e => (e.only.length === 0 || e.only.some(d => here.indexOf(d) >= 0)) && !e.not.some(d => here.indexOf(d) >= 0));
                root.apps = relevant.map(e => Object.assign(e, {
                        "enabled": !e.hidden
                    })).sort((a, b) => a.name.localeCompare(b.name));
                root.loaded = true;
            }
        }
    }

    // exec-once and exec lines of the Hyprland config
    Process {
        id: hyprProc

        command: ["sh", "-c", "grep -rHE '^[[:space:]]*(exec(-once)?[[:space:]]*=|hl\\.exec_cmd\\()' \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr\" --include='*.conf' --include='*.lua' 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split(/\r?\n/)) {
                    // hyprlang: exec-once = cmd      Lua: hl.exec_cmd("cmd")
                    const lua = line.match(/^(.*?\.lua):\s*hl\.exec_cmd\(\s*"((?:[^"\\]|\\.)*)"/);
                    const m = lua ? [null, lua[1], lua[2].replace(/\\(.)/g, "$1")] : line.match(/^(.*?\.conf):\s*exec(?:-once)?\s*=\s*(.*)$/);
                    if (!m)
                        continue;
                    // the trailing " &" is only there to detach it
                    const command = m[2].replace(/\s*&\s*$/, "").trim();
                    if (command !== "")
                        list.push({
                            "command": command,
                            "file": m[1].split("/").pop()
                        });
                }
                root.hyprland = list;
            }
        }
    }

    Component.onCompleted: refresh()
}
