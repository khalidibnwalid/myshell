pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Every Hyprland option, edited from the Settings window.
//
// What exists comes from the running Hyprland itself (`hyprctl descriptions`): name,
// description, range and choices, so the list always fits the installed version. The
// values it has right now come from `hyprctl getoption`, which includes whatever the
// hand-written hyprland.conf sets. Only what is changed here is stored (in
// config.overrides.json, as Config.hyprland.values) and written to
//
//   ~/.config/hypr/config/quickshell.conf   (hyprlang, the format 0.56 and older read)
//   ~/.config/hypr/config/quickshell.lua    (the Lua format that replaces it in 0.57)
//
// scripts/apply-hyprland.sh makes the main config include them. A change is applied to
// the running session at once (hyprctl keyword, or eval on a Lua config); "reset" removes it from the file and
// reloads, which brings back what the hand-written config says.
Singleton {
    id: root

    readonly property string hyprDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr"

    // [{ name, category, group, key, title, description, kind, def, min, max, choices }]
    property var options: []
    // name -> option
    property var optionMap: ({})
    // name -> the value in use right now
    property var live: ({})
    property string version: ""
    property bool loaded: false
    // Hyprland has no options list (old version) or could not be reached
    property string problem: ""

    readonly property var changed: Config.hyprland?.values ?? ({})
    readonly property int changedCount: Object.keys(changed).length
    // the active border (and the border of grouped windows) takes the shell's accent colour
    // off: nothing is written, Hyprland is left to the hand-written config
    readonly property bool enabled: Config.hyprland?.enabled ?? true
    readonly property bool accentBorder: enabled && (Config.hyprland?.accentBorder ?? true)
    // Hyprland blurs what is behind the shell's windows (layer rules, written with the options)
    readonly property bool blurLayers: enabled && (Config.hyprland?.blurLayers ?? true)
    readonly property color accent: Appearance.accentColor
    readonly property var accentKeys: ["general:col.active_border", "group:col.border_active"]
    // the format of the main config in use: "lua" or "hyprlang"
    property string format: "hyprlang"

    // sections of the options list, in the order they are shown
    readonly property var categories: [
        {
            "id": "look",
            "description": "The settings most people change: borders, gaps, blur, shadow and transparency.",
            "label": "Look",
            "icon": "palette",
            "curated": true
        },
        {
            "id": "general",
            "description": "Gaps, borders, resizing and the default layout.",
            "label": "General",
            "icon": "tune",
            "sections": ["general"]
        },
        {
            "id": "decoration",
            "description": "Rounded corners, opacity, dimming, blur and shadows.",
            "label": "Decoration",
            "icon": "blur_on",
            "sections": ["decoration"]
        },
        {
            "id": "animations",
            "description": "Whether windows, workspaces and borders animate.",
            "label": "Animations",
            "icon": "animation",
            "sections": ["animations"]
        },
        {
            "id": "input",
            "description": "Keyboard, mouse, touchpad, tablet and touchscreen behaviour.",
            "label": "Input",
            "icon": "mouse",
            "sections": ["input"]
        },
        {
            "id": "gestures",
            "description": "Touchpad and touchscreen swipes between workspaces.",
            "label": "Gestures",
            "icon": "swipe",
            "sections": ["gestures"]
        },
        {
            "id": "layouts",
            "description": "How windows are tiled: dwindle, master and scrolling.",
            "label": "Layouts",
            "icon": "dashboard",
            "sections": ["layout", "dwindle", "master", "scrolling"]
        },
        {
            "id": "group",
            "description": "Tabbed window groups and their title bars.",
            "label": "Groups",
            "icon": "tab_group",
            "sections": ["group"]
        },
        {
            "id": "cursor",
            "description": "Pointer visibility, warping and zoom.",
            "label": "Cursor",
            "icon": "arrow_selector_tool",
            "sections": ["cursor"]
        },
        {
            "id": "binds",
            "description": "How keybinds and focus movement behave.",
            "label": "Binds",
            "icon": "keyboard_command_key",
            "sections": ["binds"]
        },
        {
            "id": "misc",
            "description": "Fonts, wallpaper, variable refresh rate, window swallowing and more.",
            "label": "Misc",
            "icon": "more_horiz",
            "sections": ["misc"]
        },
        {
            "id": "render",
            "description": "Rendering, direct scan-out and XWayland.",
            "label": "Rendering",
            "icon": "monitor",
            "sections": ["render", "opengl", "xwayland"]
        },
        {
            "id": "advanced",
            "description": "Debugging, experimental and compatibility options. Change with care.",
            "label": "Advanced",
            "icon": "science",
            "sections": ["debug", "experimental", "quirks", "ecosystem", "input-capture"]
        }
    ]

    // the options that matter most, grouped, for the Look page
    readonly property var curated: [
        {
            "title": "Borders and gaps",
            "names": ["general:border_size", "general:gaps_in", "general:gaps_out", "general:col.active_border", "general:col.inactive_border", "decoration:rounding", "general:resize_on_border"]
        },
        {
            "title": "Transparency",
            "names": ["decoration:active_opacity", "decoration:inactive_opacity", "decoration:dim_inactive", "decoration:dim_strength"]
        },
        {
            "title": "Blur",
            "names": ["decoration:blur:enabled", "decoration:blur:size", "decoration:blur:passes", "decoration:blur:xray", "decoration:blur:noise", "decoration:blur:vibrancy"]
        },
        {
            "title": "Shadow",
            "names": ["decoration:shadow:enabled", "decoration:shadow:range", "decoration:shadow:render_power", "decoration:shadow:color"]
        },
        {
            "title": "Motion",
            "names": ["animations:enabled", "general:layout", "misc:vrr", "misc:enable_swallow", "misc:focus_on_activate"]
        }
    ]

    // an icon for an option, from words in its name
    readonly property var iconWords: [
        ["border", "web_asset"], ["gaps", "grid_view"], ["rounding", "rounded_corner"], ["blur", "blur_on"],
        ["opacity", "opacity"], ["dim", "brightness_low"], ["shadow", "layers"], ["anim", "animation"],
        ["col", "palette"], ["color", "palette"], ["layout", "dashboard"], ["vrr", "speed"], ["swallow", "swap_horiz"],
        ["focus", "center_focus_strong"], ["cursor", "arrow_selector_tool"], ["touch", "touch_app"],
        ["scroll", "swap_vert"], ["sensitivity", "speed"], ["accel", "speed"], ["kb_", "keyboard"], ["key", "keyboard"],
        ["repeat", "repeat"], ["swipe", "swipe"], ["gesture", "swipe"], ["workspace", "grid_view"],
        ["fullscreen", "fullscreen"], ["float", "picture_in_picture"], ["group", "tab_group"], ["font", "text_fields"],
        ["tearing", "bolt"], ["dpms", "monitor"], ["monitor", "monitor"], ["debug", "bug_report"], ["log", "bug_report"],
        ["xwayland", "window"], ["zoom", "zoom_in"], ["scale", "aspect_ratio"], ["wallpaper", "wallpaper"],
        ["mouse", "mouse"], ["resize", "open_in_full"], ["snap", "grid_goldenratio"], ["tablet", "draw"],
        ["hide", "visibility_off"], ["warp", "near_me"], ["split", "vertical_split"], ["master", "view_sidebar"],
        ["enable", "toggle_on"]
    ]

    function iconFor(option) {
        const text = option.key.toLowerCase() + " " + option.group.toLowerCase();
        for (const pair of iconWords) {
            if (text.includes(pair[0]))
                return pair[1];
        }
        const byKind = {
            "bool": "toggle_on",
            "choice": "list",
            "int": "tune",
            "float": "tune",
            "color": "palette",
            "list": "data_array",
            "text": "text_fields"
        };
        return byKind[option.kind] || "tune";
    }

    // the page of the Hyprland wiki that explains an option
    function docsUrl(option) {
        const layouts = {
            "dwindle": "dwindle-layout",
            "master": "master-layout",
            "scrolling": "scrolling-layout"
        };
        if (layouts[option.section])
            return "https://wiki.hypr.land/configuring/layouts/" + layouts[option.section] + "/";
        const parts = option.group !== "" ? option.group.split(" ") : [];
        const anchor = parts.length > 0 ? parts[parts.length - 1] : option.section;
        return "https://wiki.hypr.land/configuring/core/config-options/#" + anchor.replace(/_/g, "-");
    }

    // the installed font families, sorted once
    property var fontCache: null

    function fonts() {
        if (fontCache === null)
            fontCache = Qt.fontFamilies().slice().sort();
        return fontCache;
    }

    // the type of an option, in words
    function typeLabel(option) {
        const labels = {
            "bool": "On / off",
            "int": "Whole number",
            "float": "Number",
            "choice": "One of a list",
            "select": "One of a list",
            "color": "Colour",
            "list": "List of numbers",
            "text": "Text",
            "font": "Font name",
            "monitor": "Monitor name"
        };
        return labels[option.kind] || option.kind;
    }

    // --- reading ------------------------------------------------------------
    function humanize(key) {
        const words = key.replace(/^col\./, "").replace(/[._-]/g, " ").trim();
        return words.charAt(0).toUpperCase() + words.slice(1);
    }

    function kindOf(option) {
        const d = option.default;
        if (typeof d === "boolean")
            return "bool";
        if (option.map)
            return "choice";
        if (Array.isArray(d))
            return "list";
        if (typeof d === "number")
            return Number.isInteger(d) ? "int" : "float";
        if (typeof d === "string" && (/^[0-9a-f]{8}( -?\d+deg)?$/i.test(d) || /(^|:)col\./.test(option.name)))
            return "color";
        return "text";
    }

    // options that take one of a few words, where the description does not list them
    readonly property var enumTable: ({
            "general:layout": ["dwindle", "master", "scrolling", "monocle"],
            "master:new_status": ["master", "slave", "inherit"],
            "master:new_on_active": ["before", "after", "none"],
            "master:orientation": ["left", "right", "top", "bottom", "center"],
            "master:center_master_fallback": ["left", "right", "top", "bottom"],
            "scrolling:direction": ["left", "right", "up", "down"],
            "render:cm_sdr_eotf": ["default", "gamma22", "gamma22force", "srgb"]
        })
    readonly property var fontOptions: ["misc:font_family", "misc:splash_font_family", "group:groupbar:font_family"]
    readonly property var monitorOptions: ["input:touchdevice:output", "input:tablet:output", "cursor:default_monitor"]

    // a text option that is really a pick from a list: [a/b/c] in the description, or the table
    function wordsFor(raw) {
        if (enumTable[raw.name])
            return enumTable[raw.name];
        const m = (raw.description || "").match(/\[([\w\-]+(?:\/[\w\-:<>]+)+)\]/);
        if (!m)
            return null;
        return m[1].split("/").filter(w => w.indexOf("<") < 0 && w.indexOf(":") < 0);
    }

    function parse(list) {
        const out = [];
        const map = {};
        for (const raw of list) {
            const parts = raw.name.split(":");
            const section = parts[0];
            const option = {
                "name": raw.name,
                "section": section,
                "group": parts.length > 2 ? parts.slice(1, -1).join(" ") : "",
                "key": parts[parts.length - 1],
                "title": humanize(parts[parts.length - 1]),
                "description": raw.description || "",
                "def": raw.default,
                "min": raw.min ?? null,
                "max": raw.max ?? null,
                "choices": raw.map ? raw.map.map(m => ({
                            "label": humanize(Object.keys(m)[0]),
                            "value": m[Object.keys(m)[0]]
                        })).sort((a, b) => a.value - b.value) : []
            };
            option.kind = kindOf(raw);
            if (option.kind === "text") {
                const words = wordsFor(raw);
                if (fontOptions.indexOf(raw.name) >= 0) {
                    option.kind = "font";
                } else if (monitorOptions.indexOf(raw.name) >= 0) {
                    option.kind = "monitor";
                } else if (words) {
                    option.kind = "select";
                    // an option that is unset by default can be left on its default
                    option.choices = (raw.default === "[[EMPTY]]" ? [
                            {
                                "label": "Default",
                                "value": ""
                            }
                        ] : []).concat(words.map(w => ({
                                    "label": humanize(w),
                                    "value": w
                                })));
                }
            }
            // a number with a small range of fractions (opacity, strength) is a float
            if (option.kind === "int" && option.min !== null && option.max !== null && option.max - option.min <= 1)
                option.kind = "float";
            out.push(option);
            map[option.name] = option;
        }
        options = out;
        optionMap = map;
    }

    // the value of an option as hyprctl getoption prints it
    function fromLive(entry) {
        // 0.57 reports booleans as "bool", gaps as "css" and colours as "gradient"
        for (const type of ["bool", "int", "float", "str", "custom", "css", "gradient"]) {
            if (!(type in entry))
                continue;
            let v = entry[type];
            if (type === "str" && typeof v === "string" && v.length >= 2 && v.startsWith("\"") && v.endsWith("\""))
                v = v.substring(1, v.length - 1);
            return v;
        }
        if ("vec2" in entry)
            return entry.vec2;
        return undefined;
    }

    function parseLive(text) {
        const next = {};
        for (const line of text.split("\n")) {
            if (!line.startsWith("{"))
                continue;
            try {
                const entry = JSON.parse(line);
                const v = fromLive(entry);
                if (v !== undefined)
                    next[entry.option] = v;
            } catch (e) {
            }
        }
        live = next;
        // a number that hyprctl calls a float is one
        for (const o of options) {
            if (o.kind === "int" && typeof next[o.name] === "number" && !Number.isInteger(next[o.name]))
                o.kind = "float";
        }
        loaded = true;
    }

    function refresh() {
        if (options.length === 0)
            return;
        liveProc.command = ["hyprctl", "--batch", options.map(o => "j/getoption " + o.name).join(" ; ")];
        liveProc.running = true;
    }

    // the value shown for an option
    function valueOf(name) {
        const o = optionMap[name];
        if (enabled && name in changed)
            return changed[name];
        if (name in live)
            return live[name];
        return o ? o.def : undefined;
    }

    function isChanged(name) {
        return enabled && name in changed || (accentBorder && accentKeys.indexOf(name) >= 0);
    }

    function isManaged(name) {
        return accentBorder && accentKeys.indexOf(name) >= 0;
    }

    function inCategory(cat) {
        return options.filter(o => cat.sections.indexOf(o.section) >= 0);
    }

    function search(query) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        return options.filter(o => o.name.toLowerCase().includes(q) || o.title.toLowerCase().includes(q) || o.description.toLowerCase().includes(q)).slice(0, 80);
    }

    // --- colours ----------------------------------------------------------------
    function pad(n) {
        const h = Math.round(n * 255).toString(16);
        return h.length < 2 ? "0" + h : h;
    }

    // "rgba(rrggbbaa)" or hyprctl's "aarrggbb 45deg" as a colour
    function toColor(v) {
        const s = String(v || "");
        let m = s.match(/rgba?\(([0-9a-fA-F]{6,8})\)/);
        if (m) {
            const h = m[1];
            return Qt.rgba(parseInt(h.substr(0, 2), 16) / 255, parseInt(h.substr(2, 2), 16) / 255, parseInt(h.substr(4, 2), 16) / 255, h.length === 8 ? parseInt(h.substr(6, 2), 16) / 255 : 1);
        }
        m = s.match(/^([0-9a-fA-F]{8})/);
        if (m) {
            const h = m[1];
            return Qt.rgba(parseInt(h.substr(2, 2), 16) / 255, parseInt(h.substr(4, 2), 16) / 255, parseInt(h.substr(6, 2), 16) / 255, parseInt(h.substr(0, 2), 16) / 255);
        }
        return Qt.rgba(1, 1, 1, 1);
    }

    function fromColor(c) {
        return "rgba(" + pad(c.r) + pad(c.g) + pad(c.b) + pad(c.a) + ")";
    }

    // --- writing ------------------------------------------------------------
    // what goes into the files: the changes, plus the accent borders
    function managed() {
        if (!enabled)
            return {};
        const out = Object.assign({}, changed);
        if (accentBorder) {
            for (const k of accentKeys)
                out[k] = fromColor(accent);
        }
        return out;
    }

    function kindFor(name) {
        return optionMap[name] ? optionMap[name].kind : "text";
    }

    function confValue(name, v) {
        if (typeof v === "boolean")
            return v ? "true" : "false";
        if (Array.isArray(v))
            return v.join(", ");
        return String(v);
    }

    // "5 5 5 5" -> 5, or { top, right, bottom, left }
    function gapValue(v) {
        const n = String(v).trim().split(/\s+/).map(Number);
        if (n.length === 0 || n.some(isNaN))
            return 0;
        if (n.length === 1 || n.every(x => x === n[0]))
            return n[0];
        return {
            "top": n[0],
            "right": n[1] ?? n[0],
            "bottom": n[2] ?? n[0],
            "left": n[3] ?? n[1] ?? n[0]
        };
    }

    function luaValue(name, v) {
        if (typeof v === "boolean" || typeof v === "number")
            return String(v);
        if (Array.isArray(v))
            return "{" + v.join(", ") + "}";
        if (/^(general:(gaps_in|gaps_out|float_gaps))$/.test(name)) {
            const g = gapValue(v);
            return typeof g === "number" ? String(g) : "{ top = " + g.top + ", right = " + g.right + ", bottom = " + g.bottom + ", left = " + g.left + " }";
        }
        const o = optionMap[name];
        if (o && (o.kind === "int" || o.kind === "float") && !isNaN(Number(v)))
            return String(Number(v));
        return JSON.stringify(String(v));
    }

    // { general: { gaps_in: v, col: { active_border: v } } }
    function tree(values, luaStyle) {
        const root = {};
        for (const name of Object.keys(values).sort()) {
            let path = name.split(":");
            // "col.active_border" is a nested table in Lua, a dotted key in hyprlang
            if (luaStyle) {
                const flat = [];
                for (const p of path)
                    p.split(".").forEach(x => flat.push(x));
                path = flat;
            }
            let node = root;
            for (let i = 0; i < path.length - 1; i++) {
                const key = luaStyle ? path[i].replace(/-/g, "_") : path[i];
                if (typeof node[key] !== "object" || node[key] === null || "__v" in node[key])
                    node[key] = {};
                node = node[key];
            }
            const last = luaStyle ? path[path.length - 1].replace(/-/g, "_") : path[path.length - 1];
            node[last] = {
                "__v": values[name],
                "__n": name
            };
        }
        return root;
    }

    function confText(values) {
        const lines = ["# Written by the quickshell Settings (Hyprland page); changes made here are overwritten.", "# Reset a value there to hand it back to the files above."];
        const emit = (node, indent) => {
            const pad = "    ".repeat(indent);
            for (const key of Object.keys(node)) {
                const item = node[key];
                if ("__v" in item) {
                    lines.push(pad + key + " = " + confValue(item.__n, item.__v));
                } else {
                    lines.push(pad + key + " {");
                    emit(item, indent + 1);
                    lines.push(pad + "}");
                }
            }
        };
        emit(tree(values, false), 0);
        // floating windows get their border colour from a rule in the hand-written config
        // (float + workspace w[fv1-10]); a later rule with the same match wins
        if (accentBorder) {
            lines.push("");
            lines.push("windowrule = match:float 1, match:workspace w[fv1-10], border_color " + fromColor(accent));
        }
        if (blurLayers) {
            lines.push("");
            lines.push("layerrule = match:namespace ^quickshell$, blur on, ignore_alpha 0.01, no_anim on");
            lines.push("layerrule = match:namespace ^quickshell-workspaces$, blur on, ignore_alpha 0.01, animation popin 80%");
        }
        for (const l of workspaceLines(false))
            lines.push(l);
        return lines.join("\n") + "\n";
    }

    // --- one set of workspaces per screen ------------------------------------------
    // Screen k of the list gets workspaces k*N+1 .. (k+1)*N. The list is kept in the config, so
    // a screen that is unplugged keeps its rule (its workspaces then show on another screen).
    readonly property bool workspaceSplit: Config.hyprland?.workspaceSplit ?? false
    readonly property int workspaceCount: Config.hyprland?.workspaceCount ?? 5
    // the bar lists only the workspaces of its own screen (plus any past the pinned ones that it holds)
    readonly property bool barOwnWorkspaces: Config.hyprland?.barOwnWorkspaces ?? true
    readonly property bool pairKeys: Config.hyprland?.pairKeys ?? false
    readonly property var workspaceScreens: Config.hyprland?.workspaceScreens ?? []

    // adds the screens that are connected now and not yet in the list
    function rememberScreens() {
        const known = workspaceScreens.slice();
        let added = false;
        for (const m of Hyprland.monitors.values) {
            if (known.indexOf(m.name) < 0) {
                known.push(m.name);
                added = true;
            }
        }
        if (added)
            Config.setIn("hyprland", "workspaceScreens", known);
    }

    // first workspace of a screen, or 0 when it has none
    function firstWorkspace(name) {
        const k = workspaceScreens.indexOf(name);
        return k < 0 ? 0 : k * workspaceCount + 1;
    }

    // the workspace rules and the keys, as lines of the Lua or hyprlang file
    function workspaceLines(lua) {
        const lines = [];
        const screens = workspaceScreens;
        const n = workspaceCount;
        if (!workspaceSplit || screens.length === 0)
            return lines;
        lines.push("");
        for (let k = 0; k < screens.length; k++) {
            for (let i = 1; i <= n; i++) {
                const ws = k * n + i;
                const def = i === 1;
                lines.push(lua ? "hl.workspace_rule({ workspace = \"" + ws + "\", monitor = \"" + screens[k] + "\", default = " + def + " })" : "workspace = " + ws + ", monitor:" + screens[k] + ", default:" + def);
            }
        }
        if (!pairKeys)
            return lines;
        lines.push("");
        for (let i = 1; i <= 10; i++) {
            const key = i % 10;
            const idx = (i - 1) % n;
            // every screen except the one you are on first, that one last so it keeps the focus
            const items = screens.map((name, k) => name + ":" + (k * n + idx + 1)).join(" ");
            const dispatch = lua ? "hyprctl dispatch \"hl.dsp.focus({ workspace = ${p##*:} })\"" : "hyprctl dispatch workspace ${p##*:}";
            const cmd = "cur=$(hyprctl activeworkspace -j | sed -n 's/.*\"monitor\": \"\\([^\"]*\\)\".*/\\1/p'); " + "for p in " + items + "; do [ \"${p%%:*}\" = \"$cur\" ] || " + dispatch + "; done; " + "for p in " + items + "; do [ \"${p%%:*}\" = \"$cur\" ] && " + dispatch + "; done";
            if (lua) {
                lines.push("hl.unbind(\"SUPER + SHIFT + " + key + "\")");
                lines.push("hl.bind(\"SUPER + ALT + " + key + "\", hl.dsp.window.move({ workspace = " + i + ", follow = false }), { description = \"Move window silently to workspace " + i + "\" })");
                lines.push("hl.bind(\"SUPER + SHIFT + " + key + "\", hl.dsp.exec_cmd(" + JSON.stringify(cmd) + "), { description = \"Switch every screen to its workspace " + (idx + 1) + "\" })");
            } else {
                lines.push("unbind = SUPER SHIFT, " + key);
                lines.push("bind = SUPER ALT, " + key + ", movetoworkspacesilent, " + i);
                lines.push("bind = SUPER SHIFT, " + key + ", exec, " + cmd);
            }
        }
        return lines;
    }

    // also when the config file is edited by hand, or read back at startup
    onWorkspaceSplitChanged: writeTimer.restart()
    onWorkspaceCountChanged: writeTimer.restart()
    onPairKeysChanged: writeTimer.restart()

    function setWorkspaceSplit(on) {
        if (on)
            rememberScreens();
        Config.setIn("hyprland", "workspaceSplit", on);
        needsReload = true;
        writeTimer.restart();
    }

    function setWorkspaceCount(n) {
        Config.setIn("hyprland", "workspaceCount", Math.max(1, Math.min(10, Math.round(n))));
        needsReload = true;
        writeTimer.restart();
    }

    function setBarOwnWorkspaces(on) {
        Config.setIn("hyprland", "barOwnWorkspaces", on);
    }

    function setPairKeys(on) {
        Config.setIn("hyprland", "pairKeys", on);
        needsReload = true;
        writeTimer.restart();
    }

    // the hl.config({ ... }) call for some values, as lines
    function luaConfig(values) {
        const lines = ["hl.config({"];
        const emit = (node, indent) => {
            const pad = "    ".repeat(indent);
            for (const key of Object.keys(node)) {
                const item = node[key];
                if ("__v" in item) {
                    lines.push(pad + key + " = " + luaValue(item.__n, item.__v) + ",");
                } else {
                    lines.push(pad + key + " = {");
                    emit(item, indent + 1);
                    lines.push(pad + "},");
                }
            }
        };
        emit(tree(values, true), 1);
        lines.push("})");
        return lines;
    }

    function luaText(values) {
        const lines = ["-- Written by the quickshell Settings (Hyprland page); changes made here are overwritten.", "-- Reset a value there to hand it back to the files above."].concat(luaConfig(values));
        if (accentBorder)
            lines.push("", "hl.window_rule({ name = \"quickshell-accent-border\", match = { float = true, workspace = \"w[fv1-10]\" }, border_color = \"" + fromColor(accent) + "\" })");
        if (blurLayers) {
            lines.push("");
            lines.push("hl.layer_rule({ name = \"quickshell-blur\", match = { namespace = \"^quickshell$\" }, blur = true, ignore_alpha = 0.01, no_anim = true })");
            lines.push("hl.layer_rule({ name = \"quickshell-workspaces-blur\", match = { namespace = \"^quickshell-workspaces$\" }, blur = true, ignore_alpha = 0.01, animation = \"popin 80%\" })");
        }
        for (const l of workspaceLines(true))
            lines.push(l);
        return lines.join("\n") + "\n";
    }

    // changes to the running session. A Lua config (0.57) has no `hyprctl keyword`, the
    // values go through `hyprctl eval`; a hyprlang one still takes keyword.
    function applyLive(values) {
        const names = Object.keys(values);
        if (names.length === 0)
            return;
        if (format === "lua")
            Quickshell.execDetached(["hyprctl", "eval", luaConfig(values).join(" ")]);
        else
            Quickshell.execDetached(["hyprctl", "--batch", names.map(n => "keyword " + n + " " + confValue(n, values[n])).join(" ; ")]);
    }

    function accentValues() {
        const out = {};
        for (const k of accentKeys)
            out[k] = fromColor(accent);
        return out;
    }

    property bool needsReload: false
    property bool startup: true
    property bool ensured: false

    function write() {
        const values = managed();
        const conf = confText(values);
        // at startup a reload is only needed when the accent changed since the file was written
        if (startup) {
            startup = false;
            let old = "";
            try {
                old = confFile.text();
            } catch (e) {
            }
            if (old !== conf)
                needsReload = true;
        }
        confFile.setText(conf);
        luaFile.setText(luaText(values));
        if (!ensured) {
            ensured = true;
            Quickshell.execDetached([Quickshell.shellDir + "/scripts/apply-hyprland.sh", hyprDir]);
        }
        if (needsReload) {
            needsReload = false;
            reloadTimer.restart();
        }
    }

    // --- changing -------------------------------------------------------------
    property var pending: ({})

    function set(name, value) {
        const values = Object.assign({}, changed);
        values[name] = value;
        Config.setIn("hyprland", "values", values);
        const next = Object.assign({}, live);
        next[name] = value;
        live = next;
        pending[name] = value;
        flushTimer.restart();
        writeTimer.restart();
    }

    function reset(name) {
        if (!(name in changed))
            return;
        const values = Object.assign({}, changed);
        delete values[name];
        Config.setIn("hyprland", "values", values);
        needsReload = true;
        writeTimer.restart();
    }

    function resetAll() {
        Config.setIn("hyprland", "values", {});
        needsReload = true;
        writeTimer.restart();
    }

    // hands everything back to the hand-written config, or takes it over again
    function setEnabled(on) {
        Config.setIn("hyprland", "enabled", on);
        needsReload = true;
        writeTimer.restart();
    }

    function setBlurLayers(on) {
        Config.setIn("hyprland", "blurLayers", on);
        needsReload = true;
        writeTimer.restart();
    }

    function setAccentBorder(on) {
        Config.setIn("hyprland", "accentBorder", on);
        needsReload = true;
        writeTimer.restart();
    }

    // changes go to the running session right away, a few at a time
    Timer {
        id: flushTimer

        interval: 60
        onTriggered: {
            const values = root.pending;
            root.pending = ({});
            root.applyLive(values);
        }
    }

    Timer {
        id: writeTimer

        interval: 500
        onTriggered: root.write()
    }

    Timer {
        id: reloadTimer

        interval: 400
        onTriggered: {
            Quickshell.execDetached(["hyprctl", "reload"]);
            refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer

        interval: 900
        onTriggered: root.refresh()
    }

    // the accent changed: the borders follow
    onAccentChanged: {
        if (accentBorder && loaded) {
            applyLive(accentValues());
            // the rule for floating windows only changes with a reload
            needsReload = true;
            writeTimer.restart();
        }
    }

    FileView {
        id: confFile

        path: root.hyprDir + "/config/quickshell.conf"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: luaFile

        path: root.hyprDir + "/config/quickshell.lua"
        printErrors: false
    }

    // --- loading ----------------------------------------------------------------
    function start() {
        descProc.running = true;
        versionProc.running = true;
        formatProc.running = true;
    }

    Component.onCompleted: start()

    // the first time the options are known, write the files (the accent borders, and the
    // include line in the main config)
    property bool firstWrite: true

    onLoadedChanged: {
        if (loaded && firstWrite) {
            firstWrite = false;
            if (accentBorder)
                applyLive(accentValues());
            writeTimer.restart();
        }
    }

    Process {
        id: descProc

        command: ["hyprctl", "descriptions", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.parse(JSON.parse(text));
                    root.refresh();
                } catch (e) {
                    root.problem = "Couldn't read the option list from Hyprland. Is it running, and version 0.50 or newer?";
                }
            }
        }
    }

    Process {
        id: liveProc

        stdout: StdioCollector {
            onStreamFinished: root.parseLive(text)
        }
    }

    Process {
        id: versionProc

        command: ["hyprctl", "version", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.version = JSON.parse(text).tag || "";
                } catch (e) {
                }
            }
        }
    }

    // which main config Hyprland reads: hyprland.lua wins when it exists
    Process {
        id: formatProc

        command: ["sh", "-c", "[ -f \"$1/hyprland.lua\" ] && echo lua || echo hyprlang", "sh", root.hyprDir]

        stdout: StdioCollector {
            onStreamFinished: root.format = text.trim() || "hyprlang"
        }
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                refreshTimer.restart();
        }

        target: Hyprland
    }

    // qs ipc call hyprland set general:gaps_out 8   (a JSON value, or plain text)
    // qs ipc call hyprland reset general:gaps_out | reset_all | get general:gaps_out
    IpcHandler {
        function set(name: string, value: string): string {
            if (!(name in root.optionMap))
                return "unknown option " + name;
            let v = value;
            try {
                v = JSON.parse(value);
            } catch (e) {
            }
            root.set(name, v);
            return "ok";
        }

        function reset(name: string): void {
            root.reset(name);
        }

        function enable(): void {
            root.setEnabled(true);
        }

        function disable(): void {
            root.setEnabled(false);
        }

        function reset_all(): void {
            root.resetAll();
        }

        function get(name: string): string {
            return JSON.stringify(root.valueOf(name));
        }

        target: "hyprland"
    }
}
