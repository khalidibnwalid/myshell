pragma Singleton

import "../config"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Singleton {
    id: searchService

    // Persistence Hub
    property var usageData: ({})
    readonly property url storageUrl: Qt.resolvedUrl("../usage_stats.json")
    readonly property string storagePath: storageUrl.toString().replace("file://", "")
    
    // Application tracking setup
    property var allApps: {
        const apps = DesktopEntries.applications.values;
        const mapped = [];
        for (let i = 0; i < apps.length; i++) {
            const entry = apps[i];
            const appId = entry.id;
            mapped.push({
                "id": appId,
                "name": entry.name,
                "description": entry.comment,
                "image": entry.icon,
                "type": "app",
                "execute": function() {
                    entry.execute();
                    Qt.callLater(() => {
                        loaderProcess.running = true; 
                        let data = searchService.usageData;
                        data[appId] = (data[appId] || 0) + 1;
                        searchService.usageData = data;
                        saveUsage();
                    });
                }
            });
        }
        return mapped;
    }

    function saveUsage() {
        try {
            const content = JSON.stringify(searchService.usageData);
            const safeContent = content.replace(/'/g, "'\\''");
            Quickshell.execDetached(["sh", "-c", "echo '" + safeContent + "' > '" + storagePath + "'"]);
        } catch(e) { console.log("Save failure: " + e); }
    }

    function isCalculator(query) {
        return /^[\d\s\+\-\*\/\(\)\.\^]+$/.test(query) && /[\+\-\*\/\^]/.test(query);
    }

    function isPathSearch(query) {
        return query.startsWith("/") || query.startsWith("~") || query.startsWith("./") || query.includes("/");
    }

    // Apps are matched synchronously and shown at once; files follow from a
    // background `find`, so typing never waits on the disk.
    property var appResults: []
    property var fileResults: []
    // pages of the Settings window (and Hyprland options) that match
    property var settingsResults: []
    property string fileQuery: ""
    property int generation: 0

    property var webResults: []

    // --- web search & bangs -------------------------------------------------
    // "!yt cats" or "cats !yt" searches YouTube; a query without a bang gets a
    // "search the web" row using Config.search.defaultBang. %s is the query.
    readonly property var builtinBangs: ({
        "g": { "name": "Google", "url": "https://www.google.com/search?q=%s" },
        "ddg": { "name": "DuckDuckGo", "url": "https://duckduckgo.com/?q=%s" },
        "yt": { "name": "YouTube", "url": "https://www.youtube.com/results?search_query=%s" },
        "gh": { "name": "GitHub", "url": "https://github.com/search?q=%s" },
        "w": { "name": "Wikipedia", "url": "https://en.wikipedia.org/w/index.php?search=%s" },
        "aw": { "name": "ArchWiki", "url": "https://wiki.archlinux.org/index.php?search=%s" },
        "aur": { "name": "AUR", "url": "https://aur.archlinux.org/packages?K=%s" },
        "r": { "name": "Reddit", "url": "https://www.reddit.com/search/?q=%s" },
        "so": { "name": "Stack Overflow", "url": "https://stackoverflow.com/search?q=%s" },
        "npm": { "name": "npm", "url": "https://www.npmjs.com/search?q=%s" },
        "gi": { "name": "Google Images", "url": "https://www.google.com/search?tbm=isch&q=%s" },
        "gm": { "name": "Google Maps", "url": "https://www.google.com/maps/search/%s" },
        "tr": { "name": "Google Translate", "url": "https://translate.google.com/?sl=auto&text=%s" },
        // privateUrl: used by !! instead of a private browser window, so you stay signed in
        "gpt": { "name": "ChatGPT", "url": "https://chatgpt.com/?q=%s", "privateUrl": "https://chatgpt.com/?temporary-chat=true&q=%s", "verb": "Ask" },
        "gem": { "name": "Gemini", "url": "https://gemini.google.com/app?q=%s", "verb": "Ask" },
        "ai": { "name": "Google AI Mode", "url": "https://www.google.com/search?udm=50&q=%s", "verb": "Ask" },
        "grok": { "name": "Grok", "url": "https://grok.com/?q=%s", "verb": "Ask" },
        "claude": { "name": "Claude", "url": "https://claude.ai/new?q=%s", "privateUrl": "https://claude.ai/new?incognito&q=%s", "verb": "Ask" }
    })
    readonly property var bangs: Object.assign({}, builtinBangs, Config.search?.bangs ?? {})

    // opens the url in the configured browser (private window if asked) and brings it to the front
    function openUrl(url, isPrivate) {
        const browser = Config.search?.browser || "xdg-open";
        const args = isPrivate ? [browser, Config.search?.privateFlag || "--incognito", url] : [browser, url];
        Quickshell.execDetached(args);
        const cls = Config.search?.browserClass || "";
        if (cls !== "")
            Quickshell.execDetached(["sh", "-c", "sleep 0.4; hyprctl dispatch focuswindow \"class:^($1)$\"", "sh", cls]);
    }

    function bangIcon(key) {
        const custom = bangs[key]?.icon;
        if (custom)
            return custom;
        return builtinBangs[key] ? Qt.resolvedUrl("../assets/bangs/" + key + ".png").toString() : "";
    }

    function webRow(key, terms, isPrivate) {
        const bang = bangs[key];
        if (!bang)
            return null;
        // a site with its own private mode (temporary chat) uses that in the normal window
        const ownPrivate = isPrivate && !!bang.privateUrl;
        const url = (ownPrivate ? bang.privateUrl : bang.url).replace("%s", encodeURIComponent(terms));
        return {
            "id": "web:" + key,
            "name": (bang.verb || "Search") + " " + bang.name + (isPrivate ? " privately" : "") + (bang.verb ? " “" : " for “") + terms + "”",
            "description": isPrivate ? (ownPrivate ? "Temporary chat" : "Private") + "  ·  !" + key + "!" : "!" + key,
            "icon": isPrivate ? "visibility_off" : "travel_explore",
            "image": bangIcon(key),
            "type": "web",
            "execute": () => searchService.openUrl(url, isPrivate && !ownPrivate)
        };
    }

    // Rows for a query that contains a bang, or null if it has none.
    // "!yt cats" searches YouTube, "!yt! cats" or "!!yt cats" does it privately,
    // "!! cats" is a private search with the default engine.
    function bangResults(raw) {
        const m = raw.match(/(?:^|\s)(!!?)(\S*)/);
        if (!m)
            return null;
        // private: "!!yt" or a trailing mark, "!yt!"
        const trailing = m[2].endsWith("!");
        const isPrivate = m[1] === "!!" || trailing;
        const typed = (trailing ? m[2].slice(0, -1) : m[2]).toLowerCase();
        const key = typed === "" && isPrivate ? (Config.search?.defaultBang || "g") : typed;
        const terms = raw.replace(m[0], " ").replace(/\s+/g, " ").trim();
        if (bangs[key] && terms !== "")
            return [webRow(key, terms, isPrivate)];
        // still typing the bang: list the ones that match; Enter completes it
        return Object.keys(bangs).filter(k => k.startsWith(typed)).slice(0, 6).map(k => ({
            "id": "bang:" + k,
            "name": "!" + k + (isPrivate ? "!" : "") + "  " + bangs[k].name,
            "description": isPrivate ? "Private bang" : "Bang",
            "icon": "travel_explore",
            "image": bangIcon(k),
            "type": "web",
            "complete": (terms !== "" ? terms + " " : "") + "!" + k + (isPrivate ? "! " : " "),
            "execute": null
        }));
    }

    // Rest of the bang being typed at the end of the text ("!y" -> "t"), for inline completion
    function bangCompletion(text) {
        const m = text.match(/(?:^|\s)!!?([^\s!]+)$/);
        if (!m)
            return "";
        const typed = m[1].toLowerCase();
        if (bangs[typed])
            return "";
        const key = Object.keys(bangs).find(k => k.startsWith(typed));
        return key ? key.slice(typed.length) : "";
    }

    // an address: has a scheme, is localhost, or ends in a common web TLD (so "notes.png" is not one)
    function isUrl(raw) {
        if (/\s/.test(raw))
            return false;
        if (/^https?:\/\/\S+$/.test(raw) || /^localhost(:\d+)?(\/\S*)?$/.test(raw))
            return true;
        return /^[\w-]+(\.[\w-]+)*\.(com|org|net|io|dev|app|ai|me|co|edu|gov|xyz|tv|gg|sh|so|info|wiki)(:\d+)?(\/\S*)?$/i.test(raw);
    }

    function publish() {
        const list = [...appResults.slice(0, 5)];
        for (const item of orderItems) {
            if (item.id === "settings")
                list.push(...settingsResults);
            else if (item.id === "files")
                list.push(...fileResults.slice(0, fileOptions.limit));
            else if (item.id === "web")
                list.push(...webResults);
            else
                list.push(...providerResults.filter(r => r.providerId === item.id));
        }
        searchService.searchFinished(list);
    }

    // Settings pages whose name, section or keywords match, then a few Hyprland options.
    // Picking one opens the Settings window on it.
    function findSettings(query, raw) {
        const pages = source("settings") ? (WindowManager.settingsIndex || []) : [];
        const found = [];
        for (const p of pages) {
            const name = p.name.toLowerCase();
            let score = 0;
            if (name === query)
                score = 100;
            else if (name.startsWith(query))
                score = 60;
            else if (name.split(/[ &]+/).some(w => w.startsWith(query)))
                score = 45;
            else if (name.includes(query))
                score = 30;
            else if (query.length >= 3 && String(p.keywords).toLowerCase().split(" ").some(w => w.startsWith(query)))
                score = 15;
            if (score > 0)
                found.push({
                    "score": score,
                    "row": {
                        "id": "settings:" + p.key,
                        "name": p.name,
                        "description": "Settings  ·  " + p.group,
                        "icon": p.icon,
                        "type": "settings",
                        "execute": () => WindowManager.openSettings(p.key)
                    }
                });
        }
        found.sort((a, b) => b.score - a.score);
        const rows = found.slice(0, 3).map(f => f.row);
        if (source("hyprland") && source("settings") && query.length >= 3 && !isPathSearch(query)) {
            const options = HyprSettings.search(raw).filter(o => o.title.toLowerCase().includes(query) || o.name.toLowerCase().includes(query)).slice(0, 2);
            for (const o of options)
                rows.push({
                    "id": "hypr:" + o.name,
                    "name": o.title,
                    "description": "Hyprland  ·  " + o.name,
                    "icon": HyprSettings.iconFor(o),
                    "type": "settings",
                    "execute": () => WindowManager.openSettings("hyprland", o.title)
                });
        }
        return rows;
    }

    // The groups of results the launcher lists, in the order set in Settings → Launcher
    // (drag to sort). Apps are not in it: they are always the tiles at the top.
    readonly property var orderItems: {
        const items = [
            {
                "id": "settings",
                "title": "Settings",
                "description": "The Settings app, its pages and Hyprland options",
                "icon": "settings"
            }
        ];
        for (const c of SearchProviders.builtinSources.concat(SearchProviders.customSources))
            items.push({
                "id": c.id,
                "title": c.name,
                "description": c.description,
                "icon": c.icon,
                "image": SearchProviders.iconForSource(c)
            });
        for (const p of SearchProviders.providers)
            items.push({
                "id": p.id,
                "title": p.name,
                "description": "Search provider",
                "icon": "apps",
                "image": p.icon
            });
        items.push({
            "id": "files",
            "title": "Files and folders",
            "description": "Found in your home folder",
            "icon": "folder"
        });
        items.push({
            "id": "web",
            "title": "Web search",
            "description": "Search the web or open an address",
            "icon": "travel_explore"
        });
        const byId = {};
        for (const i of items)
            byId[i.id] = i;
        const out = [];
        for (const id of (Config.search?.order ?? [])) {
            if (byId[id]) {
                out.push(byId[id]);
                delete byId[id];
            }
        }
        for (const i of items) {
            if (byId[i.id])
                out.push(i);
        }
        return out;
    }

    function setOrder(ids) {
        Config.setIn("search", "order", ids);
        Qt.callLater(publish);
    }

    // How files are looked up (Settings → Launcher → Files and folders). The defaults are
    // what the launcher always did: the home folder, 5 levels deep, no hidden files,
    // leaving out node_modules and vendor, 4 results.
    readonly property var fileOptions: {
        const o = Config.search?.files ?? ({});
        return {
            "roots": o.roots ?? ["~"],
            "ignore": o.ignore ?? ["node_modules", "vendor"],
            "hidden": o.hidden ?? false,
            "depth": o.depth ?? 5,
            "limit": o.limit ?? 4
        };
    }

    function expandHome(path) {
        const home = Quickshell.env("HOME");
        return path === "~" ? home : (path.startsWith("~/") ? home + path.slice(1) : path);
    }

    function setFileOptions(change) {
        Config.setIn("search", "files", Object.assign({}, fileOptions, change));
    }

    function resetFileOptions() {
        Config.setIn("search", "files", {});
    }

    // is this source of results switched on in Settings → Launcher
    function source(name) {
        return Config.search?.sources?.[name] ?? true;
    }

    // results offered by apps (search providers) arrive a moment after the query
    Connections {
        function onChanged() {
            searchService.providerResults = SearchProviders.results;
            searchService.publish();
        }

        target: SearchProviders
    }

    property var providerResults: []

    function performSearch(query) {
        const raw = query.trim();
        query = raw.toLowerCase();
        generation++;
        fileTimer.stop();
        SearchProviders.search(query === "" ? "" : raw);
        providerResults = [];
        if (query === "") {
            appResults = [];
            settingsResults = [];
            fileResults = [];
            webResults = [];
            searchService.searchFinished([]);
            return;
        }

        const banged = bangResults(raw);
        if (banged) {
            appResults = [];
            settingsResults = [];
            fileResults = [];
            webResults = banged;
            publish();
            return;
        }

        if (isCalculator(query)) {
            // a sum is answered here, with bc; the other sources stay out of it
            SearchProviders.search("");
            providerResults = [];
            appResults = [];
            settingsResults = [];
            fileResults = [];
            webResults = [];
            let cmd = ["sh", "-c", "echo \"$1\" | bc -l | sed 's/\\.[0-9]*00$//;s/\\.$//'", "sh", query];
            proc.execSingle(cmd, "Result", "calculate");
            return;
        }

        appResults = allApps.map((item) => {
            const name = item.name.toLowerCase();
            const initials = name.split(" ").map(w => w[0]).join("");
            let matchScore = 0;
            if (name === query) matchScore = 100;
            else if (name.startsWith(query)) matchScore = 50;
            else if (initials.includes(query)) matchScore = 40;
            else if (name.includes(query)) matchScore = 20;
            let usageScore = Math.min((searchService.usageData[item.id] || 0) * 10, 100);
            item.totalScore = matchScore + (matchScore > 0 ? usageScore : 0);
            return item;
        }).filter(item => item.totalScore > 0).sort((a, b) => b.totalScore - a.totalScore).slice(0, 5);
        if (!source("apps"))
            appResults = [];
        // Settings is an app of its own: it is found as "settings", "preferences"…
        if (query.length >= 2 && source("settings") && ["settings", "preferences", "options", "configuration"].some(w => w.startsWith(query)))
            appResults = [{
                "id": "quickshell-settings",
                "name": "Settings",
                "description": "Change how the shell and the computer work",
                // a Material symbol: this is our own app, not one from the icon theme
                "symbol": "settings",
                "icon": "settings",
                "type": "app",
                "execute": () => WindowManager.openSettings("")
            }].concat(appResults.filter(a => a.name !== "Settings")).slice(0, 5);

        settingsResults = findSettings(query, raw);

        // last row: open the address, or search the web with the default bang
        if (isUrl(raw)) {
            const url = /^https?:\/\//.test(raw) ? raw : (raw.startsWith("localhost") ? "http://" : "https://") + raw;
            webResults = [{
                "id": "url",
                "name": "Open " + raw,
                "description": "Web",
                "icon": "public",
                "type": "web",
                "execute": () => searchService.openUrl(url, false)
            }];
        } else {
            const row = isPathSearch(query) ? null : webRow(Config.search?.defaultBang || "g", raw, false);
            webResults = row ? [row] : [];
        }
        if (!source("web"))
            webResults = [];

        // keep the file rows that still match while the new lookup runs, so the list does not flicker
        const plain = !isPathSearch(query);
        fileResults = plain && source("files") ? fileResults.filter(f => f.name.toLowerCase().includes(query)) : [];
        publish();

        if (source("files") && (!plain || query.length >= 2)) {
            fileQuery = query;
            fileTimer.restart();
        }
    }

    // the Material symbol for a kind of file
    function symbolFor(mime, name) {
        if (mime.startsWith("audio/"))
            return "audio_file";
        if (mime.startsWith("video/"))
            return "video_file";
        if (mime.startsWith("image/"))
            return "image";
        if (mime === "application/pdf")
            return "picture_as_pdf";
        if (/zip|tar|rar|7z|compress|archive|gzip/.test(mime))
            return "folder_zip";
        if (/json|javascript|xml|x-shellscript|x-python|x-c|x-rust|x-java|html|css|x-ruby|x-php/.test(mime) || /\.(qml|go|rs|ts|tsx|jsx|lua|sh|py|c|cpp|h|java|rb|php)$/i.test(name))
            return "code";
        return "description";
    }

    function searchFiles(query) {
        const opts = fileOptions;
        let filter = query;
        let roots = opts.roots.map(expandHome);
        if (query.startsWith("~")) filter = query.substring(1);
        else if (query.startsWith("/")) {
            // a typed path looks in that folder only
            let lastSlash = query.lastIndexOf("/");
            roots = [query.substring(0, lastSlash || 1)];
            filter = query.substring(lastSlash + 1);
        }

        // Everything is passed as arguments, never pasted into the script: the filter, the
        // depth, whether hidden files count, the folders to leave out and the folders to
        // look in (one per line). Each found file also gets a picture to preview, when it
        // has one: the thumbnail the file manager made, the image itself, or the cover of
        // audio and video (made once, kept in the cache, for the first few only).
        // Lines come back as: type, path, preview, mime.
        const findCmd = [
            "sh", "-c",
            FilePreview.setup +
            "depth=$1; filter=$2; hide=$3; ign=$4; roots=$5; set --; " +
            "while IFS= read -r n; do [ -n \"$n\" ] || continue; case \"$n\" in /*) set -- \"$@\" -not -path \"$n\" -not -path \"$n/*\";; *) set -- \"$@\" -not -path \"*/$n\" -not -path \"*/$n/*\";; esac; done <<EOF\n$ign\nEOF\n" +
            "[ \"$hide\" = 1 ] || set -- \"$@\" -not -path '*/.*'; " +
            "printf '%s\\n' \"$roots\" | while IFS= read -r r; do [ -d \"$r\" ] && find \"$r\" -maxdepth \"$depth\" -iname \"*$filter*\" \"$@\" -printf '%y\\t%p\\n' 2>/dev/null; done | head -n 12 | " +
            FilePreview.loop,
            "sh", String(opts.depth), filter, opts.hidden ? "1" : "0", opts.ignore.join("\n"), roots.join("\n")
        ];
        const gen = generation;

        fileProc.execFiles(findCmd, (rawLines) => {
            // a newer query was typed meanwhile
            if (gen !== searchService.generation)
                return;
            const results = [];
            for (let i = 0; i < rawLines.length; i++) {
                const f = rawLines[i].split("\t");
                const isDir = f[0] === "d";
                const path = f[1];
                if (!path) continue;

                const name = path.split("/").filter(Boolean).pop() || path;
                results.push({
                    "id": path,
                    "name": name,
                    "description": path,
                    // a picture of the file itself (a thumbnail, the image, an album cover), if there is one
                    "preview": f[2] || "",
                    "type": isDir ? "folder" : "file",
                    "icon": isDir ? "folder" : searchService.symbolFor(f[3] || "", name),
                    "execute": () => Quickshell.execDetached(["xdg-open", path])
                });
            }
            searchService.fileResults = results;
            searchService.publish();
        });
    }

    Timer {
        id: fileTimer

        interval: 90
        onTriggered: searchService.searchFiles(searchService.fileQuery)
    }

    signal searchFinished(var results)
    property var stdCollectFn

    Component.onCompleted: loaderProcess.running = true

    Process {
        id: loaderProcess
        command: ["cat", storagePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim() !== "") {
                    try {
                        let data = JSON.parse(this.text);
                        if (data && typeof data === 'object') searchService.usageData = data;
                    } catch(e) {}
                }
            }
        }
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: searchService.stdCollectFn(this.text)
        }
        function execSingle(cmd, desc, icon) {
            proc.command = cmd;
            proc.running = true;
            searchService.stdCollectFn = text => {
                searchService.searchFinished([{
                    "name": text.trim(),
                    "description": desc,
                    "icon": icon || "calculate",
                    "execute": null
                }]);
            };
        }
    }

    Process {
        id: fileProc
        property var callback
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.trim() !== "");
                if (fileProc.callback) fileProc.callback(lines);
            }
        }
        function execFiles(cmd, cb) {
            // drop a lookup that is still running for an older query
            fileProc.running = false;
            fileProc.command = cmd;
            fileProc.callback = cb;
            fileProc.running = true;
        }
    }
}
