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
        searchService.searchFinished([...appResults.slice(0, 5), ...fileResults.slice(0, 4), ...webResults]);
    }

    function performSearch(query) {
        const raw = query.trim();
        query = raw.toLowerCase();
        generation++;
        fileTimer.stop();
        if (query === "") {
            appResults = [];
            fileResults = [];
            webResults = [];
            searchService.searchFinished([]);
            return;
        }

        const banged = bangResults(raw);
        if (banged) {
            appResults = [];
            fileResults = [];
            webResults = banged;
            publish();
            return;
        }

        if (isCalculator(query)) {
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

        // keep the file rows that still match while the new lookup runs, so the list does not flicker
        const plain = !isPathSearch(query);
        fileResults = plain ? fileResults.filter(f => f.name.toLowerCase().includes(query)) : [];
        publish();

        if (!plain || query.length >= 2) {
            fileQuery = query;
            fileTimer.restart();
        }
    }

    function searchFiles(query) {
        let filter = query;
        let searchPath = Quickshell.env("HOME");
        if (query.startsWith("~")) filter = query.substring(1);
        else if (query.startsWith("/")) {
            let lastSlash = query.lastIndexOf("/");
            searchPath = query.substring(0, lastSlash || 1);
            filter = query.substring(lastSlash + 1);
        }

        // path and pattern are passed as arguments, never pasted into the script
        const findCmd = [
            "sh", "-c",
            "find \"$1\" -maxdepth 5 -iname \"*$2*\" -not -path '*/.*' -not -path '*/node_modules/*' -not -path '*/vendor/*' -printf '%y|%p\\n' 2>/dev/null | head -n 12",
            "sh", searchPath, filter
        ];
        const gen = generation;

        fileProc.execFiles(findCmd, (rawLines) => {
            // a newer query was typed meanwhile
            if (gen !== searchService.generation)
                return;
            const results = [];
            for (let i = 0; i < rawLines.length; i++) {
                const isDir = rawLines[i].charAt(0) === "d";
                const path = rawLines[i].substring(2);
                if (!path) continue;

                const name = path.split("/").filter(Boolean).pop() || path;
                results.push({
                    "id": path,
                    "name": name,
                    "description": path,
                    "image": isDir ? "folder" : "",
                    "type": isDir ? "folder" : "file",
                    "icon": isDir ? "folder" : "description",
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
