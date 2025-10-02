pragma Singleton

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Singleton {
    id: searchService

    property var allApps: DesktopEntries.applications.values.map(entry => ({
                "name": entry.name,
                "description": entry.comment,
                "image": entry.icon,
                "icon": undefined,
                "execute": entry.execute // optional function
            }))

    signal searchFinished(var results)

    property var stdCollectFn

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
                const singleResult = [
                    {
                        name: text.trim(),
                        description: desc,
                        icon: icon || "terminal",
                        execute: () => {}
                    }
                ];
                searchService.searchFinished(singleResult);
            };
        }
    }

    function performSearch(query) {
        query = query.toLowerCase();
        if (query.trim() === "") {
            searchService.searchFinished([]);
            return;
        }

        if (query.includes(":")) {
            const regex = /:(?<flag>\w+)/g;
            const flags = [];

            let match;
            while ((match = regex.exec(query)) !== null) {
                flags.push(match.groups && match.groups.flag ? match.groups.flag : match[1]);
            }

            const data = query.replace(regex, "").trim();

            if (flags.length > 0) {
                switch (flags[0]) {
                case "?":
                case "h":
                case "help":
                    searchService.searchFinished([
                        {
                            name: "Available commands",
                            description: "List of available commands",
                            icon: "help"
                        },
                        {
                            name: ":app or :a",
                            description: "List all applications",
                            icon: "apps"
                        },
                        {
                            name: ":calc or :c or :calculator",
                            description: "Simple calculator using bc",
                            icon: "calculate"
                        }
                    ]);
                    break;
                case "a":
                case "app":
                    searchService.searchFinished(allApps);
                    break;
                case "c":
                case "calc":
                case "calculator":
                    if (data) {
                        const cmd = ["sh", "-c", "echo " + data + " | bc"];
                        proc.execSingle(cmd, "Calculator", "calculate");
                    } else {
                        searchService.searchFinished([]);
                    }
                    break;
                default:
                    searchService.searchFinished([]);
                }
            } else {
                searchService.searchFinished([]);
            }
        } else {
            const scoredResults = allApps.map(item => {
                const name = item.name.toLowerCase();
                const description = item.description ? item.description.toLowerCase() : "";
                let priority = 0;
                if (name.startsWith(query)) {
                    priority = 2;
                } else if (name.includes(query)) {
                    priority = 1;
                } else if (description.includes(query)) {
                    priority = 0.5;
                }
                item.priority = priority;
                return item;
            });

            const filtered = scoredResults.filter(item => item.priority > 0);
            const sorted = filtered.sort((a, b) => b.priority - a.priority);
            searchService.searchFinished(sorted);
        }
    }
}
