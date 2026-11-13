import "../config"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton

// Keyboard layouts as Hyprland has them (input:kb_layout). The list and the
// active one are read at start and again whenever Hyprland reports a switch.
Singleton {
    id: root

    // short label of the active layout, e.g. "EN"
    property string layout: "US"
    property string fullLayoutName: ""
    property int activeIndex: 0
    // xkb codes of the configured layouts, in order: ["us", "ara"]
    property var codes: []
    // xkb code -> full name ("ara" -> "Arabic")
    property var names: ({})
    // [{ index, code, name, label }]
    readonly property var layouts: codes.map((code, index) => {
        const name = names[code] || code.toUpperCase();
        return {
            "index": index,
            "code": code,
            "name": name,
            "label": parseLayout(name)
        };
    })

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

    function nextLayout() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    // switch every keyboard to the layout at this position in the list
    function setLayout(index) {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(index)]);
    }

    function refresh() {
        if (!layoutProc.running)
            layoutProc.running = true;
    }

    Component.onCompleted: refresh()

    // a switch, or a reloaded Hyprland config with different layouts
    Connections {
        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded")
                refreshSoon.restart();
        }

        target: Hyprland
    }

    Timer {
        id: refreshSoon

        interval: 60
        onTriggered: root.refresh()
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
                        if (keyboard) {
                            root.activeIndex = keyboard.active_layout_index || 0;
                            const codes = String(keyboard.layout || "").split(",").map(c => c.trim()).filter(Boolean);
                            if (JSON.stringify(codes) !== JSON.stringify(root.codes))
                                root.codes = codes;
                        }
                    }
                } catch (e) {
                }
            }
        }

    }

    // full layout names from the system's xkb list
    Process {
        running: true
        command: ["sed", "-n", "/^! layout/,/^! variant/p", "/usr/share/X11/xkb/rules/evdev.lst"]

        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^\s+(\S+)\s+(.+)$/);
                    if (m)
                        map[m[1]] = m[2].trim();
                }
                root.names = map;
            }
        }
    }

}
