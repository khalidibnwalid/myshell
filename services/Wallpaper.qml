pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../config/"

Singleton {
    id: root

    function apply() {
        const path = Config.appearance.wallpaper;
        wallpaperProc.running = false;
        if (path) {
            wallpaperProc.command = ["sh", "-c", "pkill -x swaybg 2>/dev/null || true; exec swaybg -i \"$1\" -m fill", "sh", path];
        } else {
            wallpaperProc.command = ["pkill", "-x", "swaybg"];
        }
        wallpaperProc.running = true;
    }

    Connections {
        target: Config.appearance
        function onWallpaperChanged() {
            root.apply();
        }
    }

    Process {
        id: wallpaperProc
        running: false
    }
}
