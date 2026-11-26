pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Io

// What is wrong with the shell, for Settings → Health (and the tool list on the About page).
// Every check is a short command run by refresh(), only when a page asks: missing tools, helpers that
// cannot be built, errors in the shell's log, the Hyprland include lines, the apps' desktop entries and a
// few services (notifications, polkit agent, file chooser portal). `problems` lists what needs a look;
// fix(action) runs one of the shell's own safe fixes (a build into the cache, the apply/install scripts).
Singleton {
    id: root

    // command -> what stops working without it; "a|b" means either one
    readonly property var tools: ({
            "nmcli": "Wi-Fi",
            "brightnessctl": "screen brightness",
            "swaybg": "wallpaper",
            "cliphist": "clipboard history",
            "wl-copy": "clipboard, screenshots and copying images in Paint",
            "wtype": "paste from the clipboard menu",
            "grim": "screenshots",
            "slurp": "area selection",
            "wl-screenrec|wf-recorder": "screen recording",
            "hyprpicker": "colour picker",
            "notify-send": "capture notifications",
            "tesseract": "Extract text from a screen area",
            "zbarimg": "reading QR codes in the screenshot selector",
            "udevadm": "camera on and off message",
            "bc": "calculator in the launcher",
            "hyprsunset": "night light",
            "matugen": "colours from the wallpaper",
            "sensors": "temperatures",
            "lspci": "graphics information",
            "gio": "default apps and file previews in the launcher",
            "xdg-mime": "changing default apps",
            "busctl": "results from apps in the launcher",
            "python3": "recent files, VS Code and browser history in the launcher, and the apps' desktop entries",
            "ffmpegthumbnailer": "album covers and video frames in the launcher",
            "ffprobe": "tags and covers in the Audio player",
            "ffmpeg": "covers in the Audio player",
            "mpv": "playing sound in the Audio player",
            "go": "building the small helpers: the MPRIS side of the Audio player, the pixel engine of Paint and the keyrings on the Passwords & keys page",
            "gnome-keyring-daemon": "keyrings and saved passwords on the Passwords & keys page",
            "ssh-keygen": "SSH keys on the Passwords & keys page",
            "gpg": "GPG keys on the Passwords & keys page",
            "udisksctl": "mounting and ejecting drives",
            "lpstat": "printers",
            "hostnamectl": "changing the computer name",
            "timedatectl": "time zone and clock settings",
            "localectl": "language and formats",
            "gnome-control-center": "adding online accounts"
        })
    // tool keys that were not found ("a|b" when neither was)
    property var missingTools: []
    property bool toolsChecked: false

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/quickshell"
    readonly property string dataDir: Quickshell.env("XDG_DATA_HOME") || home + "/.local/share"
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string hyprDir: configDir + "/hypr"
    readonly property string desktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || "hyprland").split(":")[0].toLowerCase() || "hyprland"

    // the compiled helpers: folder under helpers/, folder and file in the cache, what builds it, what uses it
    readonly property var helpers: [
        {
            "id": "audio-mpris",
            "sub": "audio",
            "bin": "audio-mpris",
            "needs": ["go"],
            "name": "Media controls of the Audio player",
            "on": Apps.isEnabled("audio")
        },
        {
            "id": "audio-wave",
            "sub": "audio",
            "bin": "audio-wave",
            "needs": ["go"],
            "name": "Sound waves",
            "on": Config.bar.waves || (Config.widgets.enabled && (Config.widgetItems || []).some(w => w.type === "waves"))
        },
        {
            "id": "paint-engine",
            "sub": "paint",
            "bin": "paint-engine",
            "needs": ["go"],
            "name": "Pixel engine of Paint",
            "on": Apps.isEnabled("paint")
        },
        {
            "id": "keyring",
            "sub": "keyring",
            "bin": "keyring",
            "needs": ["go"],
            "name": "Keyrings on the Passwords & keys page",
            "on": true
        },
        {
            "id": "portal-filechooser",
            "sub": "portal",
            "bin": "portal-filechooser",
            "needs": ["go"],
            "name": "The shell's file dialogs",
            "on": Config.fileChooser.enabled
        },
        {
            "id": "ime",
            "sub": "ime",
            "bin": "qs-ime",
            "needs": ["cc", "wayland-scanner", "pkg-config", "headers"],
            "name": "Autocomplete input method",
            "on": Config.autocomplete.enabled
        }
    ]
    // id -> { built, stale }
    property var helperState: ({})
    // build tools found: { go: true, cc: true, ... }
    property var buildTools: ({})
    // id -> last lines of a failed build
    property var buildErrors: ({})

    // ERROR/TypeError/ReferenceError lines since the last "Configuration Loaded"
    property var logErrors: []
    // the Qt warning of the qs program itself ("built against Qt X but the system has Y")
    property string qtWarning: ""

    // { lua, conf, qsConf, qsLua, kbConf, kbConfIn, kbLua, kbLuaIn } as booleans
    property var hypr: ({})
    property var hyprErrors: []

    // app ids (and "settings", "notepad") whose desktop entry or icon is missing or points nowhere
    property var brokenEntries: []

    // { notifyPid, notifyComm, portal, fcPid, fcCmd, portalFile, portalConf, confOurs, confPrefers, gtk, agents }
    property var svc: ({})

    property bool loaded: false
    readonly property bool checking: toolsProc.running || helpersProc.running || logProc.running || hyprProc.running || entriesProc.running || svcProc.running
    // the fix that runs now ("" when none)
    property string busy: ""

    // [{ kind, title, items: [{ key, icon, title, description, fix, action, copy, lines }] }]
    readonly property var groups: {
        const out = [];
        const add = (kind, title, items) => {
            if (items.length > 0)
                out.push({
                    "kind": kind,
                    "title": title,
                    "items": items
                });
        };
        add("tools", "Missing tools", toolProblems());
        add("helpers", "Helpers", helperProblems());
        add("shell", "Quickshell", logProblems());
        add("hyprland", "Hyprland", hyprProblems());
        add("apps", "Apps in the launcher", entryProblems());
        add("services", "Services", serviceProblems());
        return out;
    }
    readonly property int problemCount: groups.reduce((n, g) => n + g.items.length, 0)

    function refresh() {
        checkTools();
        for (const p of [helpersProc, logProc, hyprProc, entriesProc, svcProc]) {
            if (!p.running)
                p.running = true;
        }
    }

    function checkTools() {
        if (!toolsProc.running)
            toolsProc.running = true;
    }

    // --- what is wrong --------------------------------------------------------
    function toolLabel(key) {
        return key.split("|").join(" or ");
    }

    function toolProblems() {
        return missingTools.map(t => ({
                    "key": "tool:" + t,
                    "icon": "error",
                    "title": toolLabel(t) + (t.indexOf("|") >= 0 ? " is not installed (either one will do)" : " is not installed"),
                    "description": "Needed for " + tools[t]
                }));
    }

    function helperProblems() {
        if (!loaded)
            return [];
        const out = [];
        for (const h of helpers) {
            const s = helperState[h.id];
            if (!h.on || !s)
                continue;
            const lacking = h.needs.filter(t => !buildTools[t]).map(t => t === "headers" ? "the wayland, libxkbcommon and pango headers" : t);
            const error = buildErrors[h.id];
            const item = {
                "key": "helper:" + h.id,
                "icon": "error",
                "title": "",
                "description": "",
                "fix": "",
                "action": "build:" + h.id
            };
            if (error) {
                item.title = h.name + " failed to build";
                item.description = error;
                item.fix = "Build again";
                item.copy = error;
            } else if (!s.built && lacking.length > 0) {
                item.title = h.name + " cannot be built";
                item.description = "Install " + lacking.join(", ") + " to build helpers/" + h.id;
                item.fix = "";
            } else if (s.stale && lacking.length > 0) {
                item.title = h.name + " cannot be rebuilt";
                item.description = "helpers/" + h.id + " changed since it was built, and " + lacking.join(", ") + " is missing, so it fails to start";
                item.fix = "";
            } else if (!s.built) {
                item.icon = "construction";
                item.title = h.name + " is not built yet";
                item.description = "It is built into the cache the first time it is used; build it now to see that it works";
                item.fix = "Build now";
            } else {
                continue;
            }
            out.push(item);
        }
        return out;
    }

    function logProblems() {
        const out = [];
        if (qtWarning)
            out.push({
                "key": "qt",
                "icon": "warning",
                "title": "Quickshell was built for another Qt version",
                "description": qtWarning
            });
        if (logErrors.length > 0)
            out.push({
                "key": "log",
                "icon": "bug_report",
                "title": logErrors.length === 1 ? "1 error since the shell last loaded" : logErrors.length + " errors since the shell last loaded",
                "description": "From qs log; the newest is last",
                "copy": logErrors.join("\n"),
                "lines": logErrors.slice(-8)
            });
        return out;
    }

    function hyprProblems() {
        if (!loaded)
            return [];
        const out = [];
        const h = hypr;
        const main = h.lua ? hyprDir + "/hyprland.lua" : hyprDir + "/hyprland.conf";
        if ((Config.hyprland?.enabled ?? true) && (h.lua ? !h.qsLua : (h.conf && !h.qsConf)))
            out.push({
                "key": "hypr:include",
                "icon": "error",
                "title": "Settings made here are not loaded when Hyprland starts",
                "description": main + " has no " + (h.lua ? "dofile of config/quickshell.lua" : "source line for config/quickshell.conf") + "; Add puts it at the end",
                "fix": "Add",
                "action": "apply-hyprland"
            });
        if (h.lua && h.kbLua && !h.kbLuaIn) {
            const line = 'dofile("' + hyprDir + '/config/keyboard.lua")';
            out.push({
                "key": "hypr:keyboard-lua",
                "icon": "warning",
                "title": "Your keyboard layouts are not loaded when Hyprland starts",
                "description": "Add " + line + " to hyprland.lua (Lua configs load it by hand)",
                "copy": line
            });
        } else if (!h.lua && h.conf && h.kbConf && !h.kbConfIn) {
            out.push({
                "key": "hypr:keyboard",
                "icon": "warning",
                "title": "Your keyboard layouts are not loaded when Hyprland starts",
                "description": "hyprland.conf has no source line for config/keyboard.conf; Add applies the current layouts again, which adds it",
                "fix": Keyboard.codes.length > 0 ? "Add" : "",
                "action": "apply-keyboard",
                "copy": "source = ~/.config/hypr/config/keyboard.conf"
            });
        }
        if (hyprErrors.length > 0)
            out.push({
                "key": "hypr:errors",
                "icon": "error",
                "title": hyprErrors.length === 1 ? "Hyprland reports 1 config error" : "Hyprland reports " + hyprErrors.length + " config errors",
                "description": "From hyprctl configerrors",
                "copy": hyprErrors.join("\n"),
                "lines": hyprErrors.slice(0, 8)
            });
        return out;
    }

    function entryProblems() {
        if (!loaded || brokenEntries.length === 0)
            return [];
        const names = brokenEntries.map(id => {
            if (id === "settings")
                return "Settings";
            if (id === "notepad")
                return "Notepad";
            return Apps.manifest(id)?.name ?? id;
        });
        return [
            {
                "key": "apps",
                "icon": "apps",
                "title": names.length === 1 ? names[0] + " is missing from the app list" : names.length + " of the shell's apps are missing from the app list",
                "description": (names.length > 1 ? names.join(", ") + ": " : "") + "the desktop entry or icon is missing or points to a file that is gone; other launchers and the dock rely on them",
                "fix": "Reinstall",
                "action": "install-apps"
            }
        ];
    }

    function serviceProblems() {
        if (!loaded)
            return [];
        const out = [];
        const s = svc;
        if (s.notifyPid && s.notifyPid !== String(Quickshell.processId))
            out.push({
                "key": "notify",
                "icon": "notifications_off",
                "title": (s.notifyComm || "Another program") + " shows the notifications",
                "description": "It owns org.freedesktop.Notifications, so the shell's popups and panel stay empty. Stop it and keep it from starting (exec-once or autostart), then reload the shell",
                "fix": "Reload shell",
                "action": "reload"
            });
        if (Config.polkit.enabled && s.agents && s.agents.length > 0)
            out.push({
                "key": "polkit",
                "icon": "admin_panel_settings",
                "title": "Another polkit agent is running: " + s.agents.join(", "),
                "description": "Only one agent can answer password prompts. Remove it from exec-once or autostart, or turn off the shell's prompt on the Lock & idle page"
            });
        if (Config.fileChooser.enabled) {
            if (s.portal !== "active")
                out.push({
                    "key": "portal",
                    "icon": "folder_off",
                    "title": "xdg-desktop-portal is not running (" + (s.portal || "unknown") + ")",
                    "description": "Apps cannot open file dialogs through it, the shell's or any other",
                    "fix": "Restart it",
                    "action": "restart-portal"
                });
            if (s.portalConf && !s.confOurs && !s.confPrefers) {
                const line = "org.freedesktop.impl.portal.FileChooser=quickshell;gtk";
                out.push({
                    "key": "portal:conf",
                    "icon": "folder_off",
                    "title": "Apps still use the old file dialogs",
                    "description": configDir + "/xdg-desktop-portal/" + desktop + "-portals.conf is your own file; add " + line + " under [preferred]",
                    "copy": line
                });
            } else if (!s.portalFile) {
                out.push({
                    "key": "portal:file",
                    "icon": "folder_off",
                    "title": "The shell's file dialogs are not registered",
                    "description": "quickshell.portal is missing; the file chooser helper writes it when it starts",
                    "fix": "Reload shell",
                    "action": "reload"
                });
            }
            if (s.portal === "active" && (!s.fcPid || s.fcCmd.indexOf("--fallback") >= 0) && !(helperProblems().some(p => p.key === "helper:portal-filechooser")))
                out.push({
                    "key": "portal:helper",
                    "icon": "folder_off",
                    "title": "The shell's file dialogs are not running",
                    "description": s.fcPid ? "Only the fallback runs, which hands dialogs to the GTK portal" : "The file chooser helper is not on the bus; apps get the GTK dialogs",
                    "fix": "Reload shell",
                    "action": "reload"
                });
            if (!s.gtk)
                out.push({
                    "key": "portal:gtk",
                    "icon": "warning",
                    "title": "xdg-desktop-portal-gtk is not installed",
                    "description": "While the shell is not running, file dialogs fall back to it"
                });
        }
        return out;
    }

    // --- fixes ----------------------------------------------------------------
    function fix(action) {
        if (busy !== "" || !action)
            return;
        if (action === "reload") {
            Quickshell.reload(true);
            return;
        }
        if (action === "apply-keyboard") {
            Keyboard.apply(Keyboard.codes, Keyboard.variantList, Keyboard.switchOption);
            refreshSoon.restart();
            return;
        }
        let cmd = null;
        if (action.startsWith("build:")) {
            const id = action.slice(6);
            const h = helpers.find(x => x.id === id);
            if (!h)
                return;
            cmd = ["sh", "-c", 'out=$("$1/helpers/$2/build.sh" "$3" 2>&1 >/dev/null); rc=$?; printf "%s\\n" "$out" | tail -n 6; echo "@@rc=$rc"', "sh", Quickshell.shellDir, id, cacheDir + "/" + h.sub];
        } else if (action === "apply-hyprland") {
            cmd = [Quickshell.shellDir + "/scripts/apply-hyprland.sh", hyprDir];
        } else if (action === "install-apps") {
            cmd = [Quickshell.shellDir + "/scripts/install-app-icons.sh", Quickshell.shellDir].concat(Apps.disabledIds);
        } else if (action === "restart-portal") {
            cmd = ["systemctl", "--user", "restart", "xdg-desktop-portal"];
        }
        if (!cmd)
            return;
        busy = action;
        fixProc.command = cmd;
        fixProc.running = true;
    }

    function fixDone(text) {
        const action = busy;
        if (action.startsWith("build:")) {
            const id = action.slice(6);
            const m = /@@rc=(\d+)/.exec(text);
            const errors = Object.assign({}, buildErrors);
            if (m && m[1] === "0")
                delete errors[id];
            else
                errors[id] = text.replace(/@@rc=\d+\s*$/, "").trim() || "build.sh failed";
            buildErrors = errors;
        }
        busy = "";
        refresh();
    }

    // --- parsing --------------------------------------------------------------
    function parseHelpers(text) {
        const state = {};
        const found = {};
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            if (f[0] === "tool")
                found[f[1]] = true;
            else if (f.length === 3)
                state[f[0]] = {
                    "built": f[1] === "1",
                    "stale": f[2] === "1"
                };
        }
        helperState = state;
        buildTools = found;
        loaded = true;
    }

    function parseLog(text) {
        const lines = [];
        let qt = "";
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (!line)
                continue;
            if (line.startsWith("@@qt "))
                qt = line.slice(5);
            else if (lines.indexOf(line) < 0)
                lines.push(line);
        }
        logErrors = lines;
        qtWarning = qt;
    }

    function parseHypr(text) {
        const at = text.indexOf("@@errors");
        const flags = {};
        for (const line of (at >= 0 ? text.slice(0, at) : text).split("\n")) {
            const kv = line.split("=");
            if (kv.length === 2)
                flags[kv[0]] = kv[1] === "1";
        }
        hypr = flags;
        let errors = [];
        if (at >= 0) {
            try {
                const parsed = JSON.parse(text.slice(at + 8));
                errors = (Array.isArray(parsed) ? parsed : []).map(e => String(e).trim()).filter(Boolean);
            } catch (e) {
                errors = text.slice(at + 8).split("\n").map(e => e.trim()).filter(Boolean);
            }
        }
        hyprErrors = errors;
    }

    function parseServices(text) {
        const s = {
            "agents": []
        };
        for (const line of text.split("\n")) {
            const at = line.indexOf("=");
            if (at < 0)
                continue;
            const key = line.slice(0, at);
            const value = line.slice(at + 1).trim();
            if (key === "agent") {
                if (value && s.agents.indexOf(value) < 0)
                    s.agents.push(value);
            } else if (["portalFile", "portalConf", "confOurs", "confPrefers", "gtk"].indexOf(key) >= 0) {
                s[key] = value === "1";
            } else {
                s[key] = value;
            }
        }
        s.fcCmd = s.fcCmd || "";
        svc = s;
    }

    Process {
        id: toolsProc

        command: ["sh", "-c", "for t; do ok=; for a in $(printf %s \"$t\" | tr '|' ' '); do command -v \"$a\" >/dev/null 2>&1 && ok=1; done; [ -n \"$ok\" ] || echo \"$t\"; done", "sh"].concat(Object.keys(root.tools))

        stdout: StdioCollector {
            onStreamFinished: {
                root.missingTools = text.split("\n").filter(Boolean);
                root.toolsChecked = true;
            }
        }
    }

    // per helper: id, built (1/0), sources newer than the binary (1/0); then the build tools found
    Process {
        id: helpersProc

        command: ["sh", "-c", 'dir=$1; cache=$2; shift 2
for spec; do
    id=${spec%%:*}; rest=${spec#*:}; sub=${rest%%:*}; name=${rest#*:}
    b="$cache/$sub/$name"; e=0; s=0
    if [ -x "$b" ]; then
        e=1
        [ -n "$(find "$dir/helpers/$id" -maxdepth 1 -type f \\( -name "*.go" -o -name "*.c" -o -name go.mod -o -name build.sh \\) -newer "$b" 2>/dev/null | head -n 1)" ] && s=1
    fi
    printf "%s\\t%s\\t%s\\n" "$id" "$e" "$s"
done
for t in go cc wayland-scanner pkg-config; do command -v "$t" >/dev/null 2>&1 && printf "tool\\t%s\\n" "$t"; done
pkg-config --exists wayland-client xkbcommon pangocairo 2>/dev/null && printf "tool\\theaders\\n"
exit 0', "sh", Quickshell.shellDir, root.cacheDir].concat(root.helpers.map(h => h.id + ":" + h.sub + ":" + h.bin))

        stdout: StdioCollector {
            onStreamFinished: root.parseHelpers(text)
        }
    }

    // this instance's log, from the last "Configuration Loaded" on; the qs program's own Qt warning first
    Process {
        id: logProc

        command: ["sh", "-c", 'qs log --pid "$1" 2>&1 | sed "s/\\x1b\\[[0-9;]*m//g" | awk \'/built against Qt/ && !q { sub(/^[^:]*: /, ""); q = $0; next } /Configuration Loaded/ { n = 0; next } /ERROR|TypeError|ReferenceError/ { a[n++] = $0 } END { if (q) print "@@qt " q; for (i = 0; i < n; i++) print a[i] }\'', "sh", String(Quickshell.processId)]

        stdout: StdioCollector {
            onStreamFinished: root.parseLog(text)
        }
    }

    Process {
        id: hyprProc

        command: ["sh", "-c", 'd=$1; f() { if "$@" >/dev/null 2>&1; then echo 1; else echo 0; fi; }
echo "lua=$(f test -f "$d/hyprland.lua")"
echo "conf=$(f test -f "$d/hyprland.conf")"
echo "qsConf=$(f grep -qF config/quickshell.conf "$d/hyprland.conf")"
echo "qsLua=$(f grep -Eq "quickshell(\\.lua)?\\"" "$d/hyprland.lua")"
echo "kbConf=$(f test -f "$d/config/keyboard.conf")"
echo "kbConfIn=$(f grep -qF config/keyboard.conf "$d/hyprland.conf")"
echo "kbLua=$(f test -f "$d/config/keyboard.lua")"
echo "kbLuaIn=$(f grep -Eq "keyboard(\\.lua)?\\"" "$d/hyprland.lua")"
echo "@@errors"
hyprctl configerrors -j 2>/dev/null
exit 0', "sh", root.hyprDir]

        stdout: StdioCollector {
            onStreamFinished: root.parseHypr(text)
        }
    }

    // ids whose desktop entry or icon is missing, or whose Exec path is gone
    Process {
        id: entriesProc

        command: ["sh", "-c", 'data=$1; dir=$2; shift 2
a="$data/applications"; i="$data/icons/hicolor/scalable/apps"
check() {
    [ -f "$2" ] || { echo "$1"; return; }
    icon=$(sed -n "s/^Icon=//p" "$2" | head -n 1)
    case $icon in quickshell-*) [ -f "$i/$icon.svg" ] || { echo "$1"; return; } ;; esac
    w=$(sed -n "s/^Exec=//p" "$2" | head -n 1)
    case $w in \\"*) w=${w#\\"}; w=${w%%\\"*} ;; *) w=${w%% *} ;; esac
    case $w in /*) [ -e "$w" ] || echo "$1" ;; esac
}
check settings "$a/dev.noctalia.noctalia-qs.desktop"
[ -f "$dir/apps/Notepad/notepad.svg" ] && check notepad "$a/quickshell-notepad.desktop"
for id; do check "$id" "$a/quickshell-$id.desktop"; done
exit 0', "sh", root.dataDir, Quickshell.shellDir].concat(Apps.enabled.map(m => m.id))

        stdout: StdioCollector {
            onStreamFinished: root.brokenEntries = text.split("\n").filter(Boolean)
        }
    }

    Process {
        id: svcProc

        command: ["sh", "-c", 'data=$1; cfg=$2; desk=$3
n=$(busctl --user status org.freedesktop.Notifications 2>/dev/null)
echo "notifyPid=$(printf "%s\\n" "$n" | sed -n "s/^PID=//p")"
echo "notifyComm=$(printf "%s\\n" "$n" | sed -n "s/^Comm=//p")"
echo "portal=$(systemctl --user is-active xdg-desktop-portal 2>/dev/null)"
p=$(busctl --user status org.freedesktop.impl.portal.desktop.quickshell 2>/dev/null)
echo "fcPid=$(printf "%s\\n" "$p" | sed -n "s/^PID=//p")"
echo "fcCmd=$(printf "%s\\n" "$p" | sed -n "s/^CommandLine=//p")"
f() { if "$@" >/dev/null 2>&1; then echo 1; else echo 0; fi; }
c="$cfg/xdg-desktop-portal/$desk-portals.conf"
echo "portalFile=$(f test -f "$data/xdg-desktop-portal/portals/quickshell.portal")"
echo "portalConf=$(f test -f "$c")"
echo "confOurs=$(f grep -qF "written by the quickshell shell" "$c")"
echo "confPrefers=$(f grep -q "FileChooser=quickshell" "$c")"
echo "gtk=$(f test -x /usr/lib/xdg-desktop-portal-gtk -o -x /usr/libexec/xdg-desktop-portal-gtk)"
cat /proc/[0-9]*/comm 2>/dev/null | grep -E "^(polkit-gnome-au|polkit-kde-auth|polkit-mate-aut|polkit-efl-auth|hyprpolkitagent|lxpolkit|lxqt-policykit|xfce-polkit|soteria|mate-polkit)" | sort -u | sed "s/^/agent=/"
exit 0', "sh", root.dataDir, root.configDir, root.desktop]

        stdout: StdioCollector {
            onStreamFinished: root.parseServices(text)
        }
    }

    Process {
        id: fixProc

        stdout: StdioCollector {
            onStreamFinished: root.fixDone(text)
        }
    }

    // the keyboard script runs detached; look again once Hyprland has the change
    Timer {
        id: refreshSoon

        interval: 1500
        onTriggered: root.refresh()
    }
}
