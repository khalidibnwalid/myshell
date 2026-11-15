pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Io

// Apps that offer results to the launcher, through the search provider standard that GNOME
// apps use (org.gnome.Shell.SearchProvider2): Files, Calculator, Firefox, Settings…
// Every app that offers results is asked, as in GNOME; each can be switched off in
// Settings → Launcher. Asking can start an app in the background if it is not running.
Singleton {
    id: root

    // [{ id, desktopId, busName, objectPath, name, icon }]   (D-Bus search providers)
    property var providers: []
    // Sources that run a script which prints rows, one per line: title TAB detail TAB target.
    // `open` is how a picked target is opened: "xdg-open", "browser", or a program name.
    readonly property var builtinSources: [
        {
            "id": "cmd:recent-files",
            "name": "Recent files",
            "description": "Files you opened lately, from the desktop's recent list",
            "icon": "history",
            "files": true,
            "script": Quickshell.shellDir + "/scripts/search/recent-files.py",
            "open": "xdg-open"
        },
        {
            "id": "cmd:vscode",
            "name": "VS Code projects",
            "description": "Folders and workspaces you opened in VS Code",
            "icon": "code",
            "app": "code",
            "script": Quickshell.shellDir + "/scripts/search/vscode-recent.py",
            "open": "code"
        },
        {
            "id": "cmd:browser-history",
            "name": "Browser history",
            "description": "Pages you visited, from the history of a Chromium based browser",
            "icon": "travel_explore",
            "script": Quickshell.shellDir + "/scripts/search/browser-history.py",
            "open": "browser"
        }
    ]
    // sources added in Settings: { id, name, command, open }; the query is $1 in the command
    readonly property var customSources: (Config.search?.commandSources ?? []).map(c => ({
                "id": "cmd:custom:" + c.name,
                "name": c.name,
                "description": "Your command: " + c.command,
                "icon": "terminal",
                "command": c.command,
                "open": c.open || "xdg-open",
                "custom": true
            }))
    readonly property var sources: builtinSources.concat(customSources)
    readonly property var enabledSources: sources.filter(c => isEnabled(c.id))
    readonly property var enabled: providers.filter(p => isEnabled(p.id))
    // latest results, in the launcher's row format
    property var results: []
    property string lastQuery: ""
    property int token: 0
    // how many providers still have to answer the current query
    property int waiting: 0
    property var collected: ({})

    signal changed

    // on unless switched off, like in GNOME: an app that offers results is asked
    function isEnabled(id) {
        return (Config.search?.providers ?? ({}))[id] !== false;
    }

    function setEnabled(id, on) {
        const next = Object.assign({}, Config.search?.providers ?? ({}));
        next[id] = on;
        Config.setIn("search", "providers", next);
        if (!on)
            results = results.filter(r => r.providerId !== id);
    }

    function discover() {
        listProc.running = true;
    }

    // asks every switched-on app; the answers arrive one by one into results
    function search(raw) {
        const query = raw.trim();
        token++;
        collected = ({});
        results = [];
        lastQuery = query;
        if (query.length < 2 || (enabled.length === 0 && enabledSources.length === 0)) {
            changed();
            return;
        }
        debounce.restart();
    }

    function terms() {
        return lastQuery.split(/\s+/).filter(t => t !== "");
    }

    function run(provider, my) {
        const t = terms();
        const proc = ask.createObject(root, {
            "provider": provider,
            "stage": 0,
            "my": my,
            "command": ["busctl", "--user", "--json=short", "--timeout=2", "call", provider.busName, provider.objectPath, "org.gnome.Shell.SearchProvider2", "GetInitialResultSet", "as", String(t.length)].concat(t)
        });
        proc.running = true;
    }

    function runSource(source, my) {
        const proc = sourceProc.createObject(root, {
            "source": source,
            "my": my,
            "command": source.script ? [source.script, root.lastQuery] : ["sh", "-c", source.command, "sh", root.lastQuery]
        });
        proc.running = true;
    }

    // the icon of the app a source stands for (VS Code's for its projects, the browser's
    // for its history…), or "" when it has none and the symbol is used
    function iconForSource(source) {
        let entry = null;
        if (source.id === "cmd:browser-history")
            entry = DesktopEntries.heuristicLookup(Config.search?.browserClass || "") || DesktopEntries.heuristicLookup(Config.search?.browser || "");
        else if (source.app)
            entry = DesktopEntries.byId(source.app) || DesktopEntries.heuristicLookup(source.app);
        return entry && entry.icon ? entry.icon : "";
    }

    // fills in the previews of file rows, then shows them
    function addPreviews(rows, my) {
        FilePreview.lookup(rows.map(r => r.target), found => {
            if (my !== root.token)
                return;
            root.results = root.results.map(r => {
                const info = r.target ? found[r.target] : null;
                return info && info.preview ? Object.assign({}, r, {
                        "preview": info.preview
                    }) : r;
            });
            root.changed();
        });
    }

    // a result row of a script source; built here so picking it still works after the
    // request that produced it is gone
    function sourceRow(source, title, detail, target, preview) {
        return {
            "id": "source:" + source.id + ":" + target,
            "providerId": source.id,
            "target": target,
            "name": title,
            "description": (detail !== "" ? detail + "  ·  " : "") + source.name,
            "icon": source.icon,
            "image": iconForSource(source),
            // a picture of the thing itself (a thumbnail), when the source gives one
            "preview": preview || "",
            "type": "provider",
            "execute": () => root.openTarget(source, target)
        };
    }

    // open a target the way its source asks
    function openTarget(source, target) {
        const how = source.open || "xdg-open";
        if (how === "browser") {
            const browser = Config.search?.browser || "xdg-open";
            Quickshell.execDetached([browser, target]);
        } else {
            Quickshell.execDetached([how, target]);
        }
    }

    function iconOf(meta) {
        const icon = meta.icon;
        if (icon && icon.data && icon.data.length >= 2) {
            if (icon.data[0] === "themed" && icon.data[1] && icon.data[1].data)
                return icon.data[1].data[0] || "";
            if (icon.data[0] === "file" && icon.data[1] && icon.data[1].data)
                return String(icon.data[1].data);
        }
        const g = meta.gicon && meta.gicon.data ? String(meta.gicon.data) : "";
        if (g.startsWith("/"))
            return g;
        const m = g.match(/GThemedIcon\s+(\S+)/);
        return m ? m[1] : (g !== "" && g !== "." ? g : "");
    }

    function activate(provider, id) {
        const t = terms();
        Quickshell.execDetached(["busctl", "--user", "call", provider.busName, provider.objectPath, "org.gnome.Shell.SearchProvider2", "ActivateResult", "sasu", id, String(t.length)].concat(t).concat(["0"]));
    }

    function take(provider, metas, my) {
        if (my !== token)
            return;
        const rows = [];
        for (const m of metas) {
            const id = m.id && m.id.data;
            const name = m.name && m.name.data;
            if (!id || !name)
                continue;
            const icon = iconOf(m);
            rows.push({
                "id": "provider:" + provider.id + ":" + id,
                "providerId": provider.id,
                "name": name,
                "description": (m.description && m.description.data ? m.description.data + "  ·  " : "") + provider.name,
                // the app's own icon; the result's icon when the app has none
                "image": provider.icon || icon,
                "icon": "apps",
                "type": "provider",
                "execute": () => root.activate(provider, id)
            });
        }
        results = results.concat(rows.slice(0, 3));
        changed();
    }

    Timer {
        id: debounce

        interval: 250
        onTriggered: {
            const my = root.token;
            for (const p of root.enabled)
                root.run(p, my);
            for (const c of root.enabledSources)
                root.runSource(c, my);
        }
    }

    Component {
        id: sourceProc

        Process {
            id: sp

            required property var source
            required property int my

            environment: ({
                    "QS_BROWSER_CLASS": Config.search?.browserClass || ""
                })
            stdout: StdioCollector {
                onStreamFinished: {
                    if (sp.my === root.token) {
                        const rows = [];
                        for (const line of text.split("\n")) {
                            const f = line.split("\t");
                            if (f.length < 3 || f[0] === "")
                                continue;
                            rows.push(root.sourceRow(sp.source, f[0], f[1], f[2], f[3] || ""));
                        }
                        const shown = rows.slice(0, 3);
                        root.results = root.results.concat(shown);
                        root.changed();
                        // a source of files gets their previews from the same lookup the file search uses
                        if (sp.source.files)
                            root.addPreviews(shown, sp.my);
                    }
                    sp.destroy();
                }
            }
        }
    }

    // one request: first the ids, then what to show for them
    Component {
        id: ask

        Process {
            id: proc

            required property var provider
            required property int stage
            required property int my

            stdout: StdioCollector {
                onStreamFinished: {
                    if (proc.my !== root.token) {
                        proc.destroy();
                        return;
                    }
                    let data = null;
                    try {
                        data = JSON.parse(text);
                    } catch (e) {
                    }
                    if (!data) {
                        proc.destroy();
                        return;
                    }
                    if (proc.stage === 0) {
                        const ids = (data.data && data.data[0]) || [];
                        if (ids.length > 0) {
                            const next = ask.createObject(root, {
                                "provider": proc.provider,
                                "stage": 1,
                                "my": proc.my,
                                "command": ["busctl", "--user", "--json=short", "--timeout=2", "call", proc.provider.busName, proc.provider.objectPath, "org.gnome.Shell.SearchProvider2", "GetResultMetas", "as", String(Math.min(3, ids.length))].concat(ids.slice(0, 3))
                            });
                            next.running = true;
                        }
                    } else {
                        root.take(proc.provider, (data.data && data.data[0]) || [], proc.my);
                    }
                    proc.destroy();
                }
            }
        }
    }

    // the provider files apps install
    Process {
        id: listProc

        // every data folder the system knows: the user's, then XDG_DATA_DIRS (Flatpak apps keep theirs in their own exports folder)
        command: ["sh", "-c", "dirs=\"${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"; IFS=:; for d in $dirs; do for f in \"$d\"/gnome-shell/search-providers/*.ini; do [ -f \"$f\" ] && { echo \"FILE=$f\"; cat \"$f\"; echo; }; done; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                let cur = null;
                for (const raw of text.split(/\r?\n/)) {
                    const line = raw.trim();
                    if (line.startsWith("FILE=")) {
                        cur = {
                            "id": line.slice(5).split("/").pop().replace(/\.ini$/, ""),
                            "desktopId": "",
                            "busName": "",
                            "objectPath": "",
                            "version": 0
                        };
                        list.push(cur);
                    } else if (cur) {
                        const at = line.indexOf("=");
                        if (at < 0)
                            continue;
                        const key = line.slice(0, at);
                        const value = line.slice(at + 1);
                        if (key === "DesktopId")
                            cur.desktopId = value;
                        else if (key === "BusName")
                            cur.busName = value;
                        else if (key === "ObjectPath")
                            cur.objectPath = value;
                        else if (key === "Version")
                            cur.version = Number(value);
                    }
                }
                const unique = [];
                for (const p of list) {
                    if (!unique.some(u => u.id === p.id))
                        unique.push(p);
                }
                root.providers = unique.filter(p => p.busName !== "" && p.objectPath !== "" && p.version >= 2).map(p => {
                    const entry = DesktopEntries.byId(p.desktopId.replace(/\.desktop$/, "")) || DesktopEntries.byId(p.desktopId);
                    return Object.assign(p, {
                        "name": entry ? entry.name : p.desktopId.replace(/\.desktop$/, ""),
                        "icon": entry ? entry.icon : ""
                    });
                }).sort((a, b) => a.name.localeCompare(b.name));
            }
        }
    }

    Component.onCompleted: discover()
}
