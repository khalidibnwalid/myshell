pragma Singleton

import "../config"
import QtQuick
import Quickshell

// A software dim laid over one screen (modules/ScreenDim): the brightness of a display in percent.
// Unlike the backlight it works on every screen, and it is saved per monitor name in config.screenDim.
Singleton {
    id: root

    readonly property int minLevel: 40

    // 100 means no dim
    function levelOf(name) {
        const map = Config.screenDim || ({});
        const v = map[name];
        return typeof v === "number" ? Math.max(minLevel, Math.min(100, Math.round(v))) : 100;
    }

    function setLevel(name, percent) {
        const copy = JSON.parse(JSON.stringify(Config.screenDim || {}));
        const level = Math.max(minLevel, Math.min(100, Math.round(percent)));
        if (level >= 100)
            delete copy[name];
        else
            copy[name] = level;
        Config.setScreenDim(copy);
    }
}
