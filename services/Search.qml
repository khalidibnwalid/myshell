pragma Singleton

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

    function performSearch(query) {
        query = query.trim().toLowerCase();
        if (query === "") {
            searchService.searchFinished([]);
            return;
        }

        if (isCalculator(query)) {
            let cmd = ["sh", "-c", "echo '" + query + "' | bc -l | sed 's/\\.[0-9]*00$//;s/\\.$//'"];
            proc.execSingle(cmd, "Result", "calculate");
            return;
        }

        const scoredApps = allApps.map((item) => {
            const name = item.name.toLowerCase();
            const description = item.description ? item.description.toLowerCase() : "";
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

        if (isPathSearch(query) || query.length >= 2) {
            searchFiles(query, scoredApps);
        } else {
            searchService.searchFinished(scoredApps);
        }
    }

    function searchFiles(query, appResults) {
        let filter = query;
        let searchPath = "$HOME";
        if (query.startsWith("~")) filter = query.substring(1);
        else if (query.startsWith("/")) {
            let lastSlash = query.lastIndexOf("/");
            searchPath = query.substring(0, lastSlash || 1);
            filter = query.substring(lastSlash + 1);
        }

        // Optimized find command:
        // For directories: Force output "folder" as the icon name
        // For files: Resolve MIME-type icon via gio
        let findCmd = [
            "sh", "-c", 
            "find " + searchPath + " -maxdepth 5 -iname \"*" + filter + "*\" -not -path \"*/.*\" -not -path \"*/node_modules/*\" -not -path \"*/vendor/*\" -printf \"%p|%y\\n\" 2>/dev/null | head -n 12 | while IFS='|' read -r path type; do echo \"$path\"; if [ \"$type\" = \"d\" ]; then echo \"folder\"; else gio info -a standard::icon \"$path\" 2>/dev/null | sed -n 's/.*icon:  \\([^,]*\\).*/\\1/p' || echo \"description\"; fi; done"
        ];
        
        fileProc.execFiles(findCmd, (rawLines) => {
            const fileResults = [];
            for (let i = 0; i < rawLines.length; i += 2) {
                const path = rawLines[i];
                let iconName = (rawLines[i+1] || "").trim();
                if (!path) continue;

                const name = path.split("/").filter(Boolean).pop() || path;
                const isDir = (iconName === "folder" || iconName === "inode-directory" || iconName.includes("folder"));
                
                fileResults.push({
                    "id": path,
                    "name": name,
                    "description": path,
                    "image": isDir ? "folder" : iconName,
                    "type": isDir ? "folder" : "file",
                    "icon": isDir ? "folder" : "description",
                    "execute": () => Quickshell.execDetached(["xdg-open", path])
                });
            }

            const combined = [...appResults, ...fileResults].slice(0, 10);
            searchService.searchFinished(combined);
        });
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
            fileProc.command = cmd;
            fileProc.callback = cb;
            fileProc.running = true;
        }
    }
}
