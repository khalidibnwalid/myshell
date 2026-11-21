pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Icon lookup that follows installs. Quickshell.iconPath() is evaluated once per binding and Qt
// keeps its icon theme cache for the life of the process, so an app installed while the shell runs
// kept a missing icon until a restart. path() therefore (1) reads `revision`, so bindings look
// again whenever the installed apps change, and (2) falls back to a list of icon files that is
// rebuilt at the same moment, for icons Qt's stale cache cannot see.
Singleton {
    id: root

    property int revision: 0
    // icon name -> file path, from the icon directories (best size per name)
    property var files: ({})

    function path(name, check) {
        revision;
        const found = Quickshell.iconPath(name, true);
        if (found !== "")
            return found;
        const file = files[name];
        if (file)
            return "file://" + file;
        return check === false ? Quickshell.iconPath(name, false) : "";
    }

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            settle.restart();
        }
    }

    property int passes: 0
    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            scan.running = true;
            if (root.passes++ < 1)
                restart();
            else
                root.passes = 0;
        }
    }

    Process {
        id: scan
        command: ["sh", "-c", "find /usr/share/icons/hicolor /usr/share/pixmaps \"${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor\" \"${XDG_DATA_HOME:-$HOME/.local/share}/icons\" -maxdepth 4 \\( -type f -o -type l \\) \\( -name '*.svg' -o -name '*.png' \\) 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const best = {};
                const rank = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/\/([^/]+)\.(svg|png)$/);
                    if (!m)
                        continue;
                    const size = line.match(/\/(\d+)x\d+\//);
                    const r = line.indexOf("/scalable/") >= 0 ? 10000 : (size ? parseInt(size[1]) : 1);
                    if (!(m[1] in rank) || r > rank[m[1]]) {
                        rank[m[1]] = r;
                        best[m[1]] = line;
                    }
                }
                root.files = best;
                root.revision++;
            }
        }
    }

    Component.onCompleted: scan.running = true
}
