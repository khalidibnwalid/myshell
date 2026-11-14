import "../config"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton

// Keyboard layouts as Hyprland has them (input:kb_layout, kb_variant, kb_options).
// The state is read at start and again whenever Hyprland reports a switch or a reload;
// apply() changes it for the running session and for later ones.
Singleton {
    id: root

    readonly property string hyprDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr"

    property string fullLayoutName: ""
    property int activeIndex: 0
    // xkb codes of the configured layouts, in order: ["us", "ara"]
    property var codes: []
    // the variant of each layout ("" for the default one), same order
    property var variantList: []
    // kb_options as set, e.g. "grp:alt_shift_toggle,caps:escape"
    property string options: ""
    // the layout-switching shortcut inside the options ("" when there is none)
    readonly property string switchOption: options.split(",").map(o => o.trim()).find(o => o.startsWith("grp:")) || ""

    // everything the system offers, from the xkb rules list
    // xkb code -> full name ("ara" -> "Arabic")
    property var names: ({})
    // [{ code, name }] sorted by name
    property var available: []
    // code -> [{ name, label }]
    property var variantMap: ({})
    // [{ value: "grp:alt_shift_toggle", label: "Alt+Shift" }]
    property var switchOptions: []

    // [{ index, code, name, variant, label }]
    readonly property var layouts: codes.map((code, index) => {
        const name = names[code] || code.toUpperCase();
        return {
            "index": index,
            "code": code,
            "name": name,
            "variant": variantList[index] || "",
            "label": labelFor(name, code)
        };
    })
    // short label of the active layout, e.g. "EN"
    readonly property string layout: activeIndex >= 0 && activeIndex < layouts.length ? layouts[activeIndex].label : (fullLayoutName !== "" ? parseLayout(fullLayoutName) : "US")

    // the key of the label setting that applies to a layout name, if any
    function customKey(name) {
        const labels = Config.keyboard?.layouts ?? ({});
        return Object.keys(labels).find(key => name.includes(key)) || "";
    }

    // the label of a layout: the one set in Settings, else its code ("tr" -> "TR")
    function labelFor(name, code) {
        const key = customKey(name);
        return key !== "" ? Config.keyboard.layouts[key] : String(code).toUpperCase();
    }

    function setLabel(name, label) {
        const labels = Object.assign({}, Config.keyboard?.layouts ?? ({}));
        labels[customKey(name) || name] = label;
        Config.setIn("keyboard", "layouts", labels);
    }

    function resetLabel(name) {
        const key = customKey(name);
        if (key === "")
            return;
        const labels = Object.assign({}, Config.keyboard.layouts);
        delete labels[key];
        Config.setIn("keyboard", "layouts", labels);
    }

    // label from the active layout's full name, when the layout list is not known yet
    function parseLayout(name) {
        if (!name)
            return "??";

        const key = customKey(name);
        if (key !== "")
            return Config.keyboard.layouts[key];
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

    // Use these layouts now and keep them. variants has one entry per layout ("" = default);
    // switchOption is a grp: option or "" for none. Other kb_options are kept.
    function apply(codeList, variantsList, switchChoice) {
        if (codeList.length === 0)
            return;
        const variant = variantsList.some(v => v) ? variantsList.join(",") : "";
        const others = options.split(",").map(o => o.trim()).filter(o => o !== "" && !o.startsWith("grp:"));
        const joined = (switchChoice ? [switchChoice] : []).concat(others).join(",");
        Quickshell.execDetached([Quickshell.shellDir + "/scripts/apply-keyboard.sh", codeList.join(","), variant, joined, hyprDir]);
        // Hyprland applies the change a moment later
        refreshSoon.interval = 500;
        refreshSoon.restart();
    }

    function refresh() {
        if (!layoutProc.running)
            layoutProc.running = true;
    }

    Component.onCompleted: refresh()

    // a switch, or a reloaded Hyprland config with different layouts
    Connections {
        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded") {
                refreshSoon.interval = 60;
                refreshSoon.restart();
            }
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
                        if (!keyboard)
                            return;
                        root.fullLayoutName = keyboard.active_keymap || "";
                        root.activeIndex = keyboard.active_layout_index || 0;
                        const list = String(keyboard.layout || "").split(",").map(c => c.trim()).filter(Boolean);
                        // one variant per layout; a changed list or a changed variant replaces the property
                        const variants = String(keyboard.variant || "").split(",").map(v => v.trim());
                        const aligned = list.map((c, i) => variants[i] || "");
                        if (JSON.stringify(list) !== JSON.stringify(root.codes))
                            root.codes = list;
                        if (JSON.stringify(aligned) !== JSON.stringify(root.variantList))
                            root.variantList = aligned;
                        const opts = String(keyboard.options || "");
                        if (opts !== root.options)
                            root.options = opts;
                    }
                } catch (e) {
                }
            }
        }

    }

    // layout names, variants and switching shortcuts from the system's xkb list
    Process {
        running: true
        command: ["sed", "-n", "/^! layout/,$p", "/usr/share/X11/xkb/rules/evdev.lst"]

        stdout: StdioCollector {
            onStreamFinished: {
                const layoutNames = {};
                const layoutList = [];
                const variants = {};
                const shortcuts = [];
                let section = "";
                for (const line of text.split("\n")) {
                    if (line.startsWith("! ")) {
                        section = line.substring(2).trim();
                        continue;
                    }
                    const m = line.match(/^\s+(\S+)\s+(.+)$/);
                    if (!m)
                        continue;
                    if (section === "layout") {
                        layoutNames[m[1]] = m[2].trim();
                        layoutList.push({
                            "code": m[1],
                            "name": m[2].trim()
                        });
                    } else if (section === "variant") {
                        // "  intl   us: English (US, intl., with dead keys)"
                        const v = m[2].match(/^(\S+):\s*(.+)$/);
                        if (v) {
                            if (!variants[v[1]])
                                variants[v[1]] = [];
                            variants[v[1]].push({
                                "name": m[1],
                                "label": v[2].trim()
                            });
                        }
                    } else if (section === "option" && m[1].startsWith("grp:") && /toggle/.test(m[1])) {
                        shortcuts.push({
                            "value": m[1],
                            "label": m[2].trim()
                        });
                    }
                }
                root.names = layoutNames;
                root.available = layoutList.sort((a, b) => a.name.localeCompare(b.name));
                root.variantMap = variants;
                root.switchOptions = shortcuts;
            }
        }
    }

}
