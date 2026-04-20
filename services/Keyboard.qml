import "../config"
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property string layout: "US"
    property string fullLayoutName: ""

    function parseLayout(name) {
        if (!name)
            return "??";

        const keyboardConfig = Config.keyboard;
        if (keyboardConfig && keyboardConfig.layouts) {
            const layouts = keyboardConfig.layouts;
            // Use Object.keys to be safer with QJSValue
            const keys = Object.keys(layouts);
            for (let i = 0; i < keys.length; i++) {
                const key = keys[i];
                if (name.includes(key))
                    return layouts[key];

            }
        }
        // Handle names like "Swedish" or "Turkish"
        const match = name.match(/\((.*)\)/);
        if (match)
            return match[1].substring(0, 2).toUpperCase();

        return name.substring(0, 2).toUpperCase();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!layoutProc.running)
                layoutProc.running = true;

        }
    }

    Process {
        id: layoutProc

        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                // Silently ignore parse errors during startup

                try {
                    if (text.trim() === "")
                        return ;

                    const data = JSON.parse(text);
                    if (data && data.keyboards) {
                        const keyboard = data.keyboards.find((kb) => {
                            return kb.main;
                        }) || data.keyboards[0];
                        if (keyboard && keyboard.active_keymap) {
                            root.fullLayoutName = keyboard.active_keymap;
                            root.layout = parseLayout(keyboard.active_keymap);
                        }
                    }
                } catch (e) {
                }
            }
        }

    }

}
