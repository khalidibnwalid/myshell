import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property alias appearance: jsonAdapter.appearance
    readonly property alias layout: jsonAdapter.layout
    readonly property alias keyboard: jsonAdapter.keyboard
    readonly property alias hyprland: jsonAdapter.hyprland
    readonly property alias search: jsonAdapter.search
    readonly property alias clipboard: jsonAdapter.clipboard
    readonly property alias apps: jsonAdapter.apps
    readonly property alias capture: jsonAdapter.capture
    readonly property alias dock: jsonAdapter.dock
    readonly property alias idle: jsonAdapter.idle
    readonly property alias polkit: jsonAdapter.polkit
    readonly property alias fileChooser: jsonAdapter.fileChooser
    readonly property alias bar: jsonAdapter.bar
    readonly property alias notifications: jsonAdapter.notifications
    readonly property alias display: jsonAdapter.display
    readonly property alias autocomplete: jsonAdapter.autocomplete
    readonly property alias monitors: jsonAdapter.monitors
    readonly property alias recentColors: jsonAdapter.recentColors
    readonly property alias widgets: jsonAdapter.widgets
    readonly property alias widgetItems: jsonAdapter.widgetItems

    // colours chosen with the colour picker, newest first
    function addRecentColor(hex) {
        const value = String(hex).toLowerCase();
        const list = [value].concat((jsonAdapter.recentColors || []).filter(c => c !== value));
        jsonAdapter.recentColors = list.slice(0, 12);
    }

    readonly property var trayHiddenList: String(jsonAdapter.bar.trayHidden || "").split("|").filter(x => x !== "")

    function setTrayHidden(id, hidden) {
        const list = trayHiddenList.filter(x => x !== id);
        if (hidden)
            list.push(id);
        jsonAdapter.bar.trayHidden = list.join("|");
    }

    function setWidgetItems(value) {
        jsonAdapter.widgetItems = value;
    }

    function setMonitors(value) {
        jsonAdapter.monitors = value;
    }

    // --- where the bar is, for everything that lines up with it ---
    readonly property string barPosition: ["left", "right", "top", "bottom"].indexOf(layout.barPosition) >= 0 ? layout.barPosition : "right"
    readonly property bool barHorizontal: barPosition === "top" || barPosition === "bottom"
    // Thickness of the bar, and so the room it takes: the distance from the screen edge to the first
    // window. Every bar style keeps margin + shape + margin equal to this, so changing the style
    // never moves the windows (the floating styles leave Appearance.barEdgeMargin to the screen edge and fill the rest).
    readonly property int barSize: 50
    // side panels (quick settings, toasts, OSD) sit on the right unless the bar is on the left
    readonly property bool panelRight: barPosition !== "left"

    // The keyboard, search and clipboard sections are plain objects, so a change
    // has to replace the whole section: Config.setIn("search", "browser", "firefox")
    function setIn(section, key, value) {
        const copy = JSON.parse(JSON.stringify(jsonAdapter[section] || {}));
        copy[key] = value;
        jsonAdapter[section] = copy;
    }

    // --- config.json is the hand-written base; what the Settings window changes
    // is stored as a difference in config.overrides.json (git-ignored, generated) ---
    readonly property var objectSections: ["appearance", "layout", "capture", "dock", "autocomplete", "display", "bar", "notifications", "idle", "polkit", "fileChooser", "widgets"]
    readonly property var plainSections: ["keyboard", "hyprland", "search", "clipboard", "apps"]
    readonly property var wholeValues: ["monitors", "recentColors", "widgetItems"]
    property var baseData: ({})
    property var overrides: ({})
    property string overridesText: ""
    // false while the base is loading or the overrides are being applied, so that is not mistaken for a user change
    property bool ready: false

    function stable(v) {
        if (Array.isArray(v))
            return "[" + v.map(stable).join(",") + "]";
        if (v !== null && typeof v === "object")
            return "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + stable(v[k])).join(",") + "}";
        return JSON.stringify(v);
    }

    function snapshot() {
        const out = {};
        for (const name of objectSections) {
            const src = jsonAdapter[name];
            const section = {};
            for (const key of Object.keys(src)) {
                if (key === "objectName" || key.endsWith("Changed"))
                    continue;
                section[key] = src[key];
            }
            out[name] = section;
        }
        for (const name of plainSections)
            out[name] = JSON.parse(JSON.stringify(jsonAdapter[name] || {}));
        for (const name of wholeValues)
            out[name] = JSON.parse(JSON.stringify(jsonAdapter[name]));
        return out;
    }

    // everything that differs from config.json
    function diff() {
        const snap = snapshot();
        const out = {};
        for (const name in snap) {
            const base = baseData[name];
            if (wholeValues.indexOf(name) >= 0) {
                if (stable(snap[name]) !== stable(base))
                    out[name] = snap[name];
                continue;
            }
            for (const key in snap[name]) {
                if (stable(snap[name][key]) !== stable((base || {})[key])) {
                    out[name] = out[name] || {};
                    out[name][key] = snap[name][key];
                }
            }
        }
        return out;
    }

    function applyOverrides() {
        ready = false;
        for (const name in overrides) {
            const values = overrides[name];
            if (wholeValues.indexOf(name) >= 0) {
                jsonAdapter[name] = values;
            } else if (plainSections.indexOf(name) >= 0) {
                const copy = JSON.parse(JSON.stringify(jsonAdapter[name] || {}));
                Object.assign(copy, values);
                jsonAdapter[name] = copy;
            } else if (objectSections.indexOf(name) >= 0) {
                for (const key in values) {
                    if (key in jsonAdapter[name])
                        jsonAdapter[name][key] = values[key];
                }
            }
        }
        readyTimer.restart();
    }

    function saveOverrides() {
        overrides = diff();
        const text = JSON.stringify(overrides, null, 4) + "\n";
        if (text !== overridesText) {
            overridesText = text;
            overridesFile.setText(text);
        }
    }

    Component.onCompleted: {
        try {
            overridesText = overridesFile.text();
            overrides = JSON.parse(overridesText);
        } catch (e) {
            overrides = ({});
        }
    }

    FileView {
        id: overridesFile

        path: Qt.resolvedUrl("../config.overrides.json")
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: file

        watchChanges: true
        onFileChanged: {
            root.ready = false;
            reload();
        }
        onLoaded: {
            try {
                root.baseData = JSON.parse(file.text());
            } catch (e) {
                root.baseData = ({});
            }
            root.applyOverrides();
        }
        // changes made in the Settings window go to config.overrides.json
        onAdapterUpdated: {
            if (root.ready)
                saveTimer.restart();
        }
        path: Qt.resolvedUrl("../config.json")

        JsonAdapter {
            id: jsonAdapter

            property JsonObject appearance

            appearance: JsonObject {
                property string bgColor: "#131317"
                property string fgColor: "#e5e1e7"
                property string accentColor: "#c2c1ff"
                property string accentColorLight: "#E3E3FA"
                property string wallpaper: ""
                // folder shown in the wallpaper picker
                property string wallpaperDir: "~/Pictures/Wallpapers"
                property string highlightColor: "#54545f"
                property string borderColor: "#000000"
                property real opacity: 0.5
                property real settingsOpacity: 1
                property string fontFamily: "Adwaita Sans"
                // the look of the bar: classic, capsule, islands or inset (see modules/Bar/Bar.qml)
                property string barStyle: "classic"
            }

            property JsonObject layout

            layout: JsonObject {
                property string barPosition: "right"
            }

            // screenshots and screen recordings
            property JsonObject capture

            capture: JsonObject {
                // also save each screenshot as a file (it is always copied)
                property bool autoSave: false
                property string screenshotDir: "~/Pictures/Screenshots"
                property string recordingDir: "~/Videos"
                property bool recordAudio: false
                // tesseract languages for "Extract text", joined with + (eng+ara)
                property string ocrLanguages: "eng"
            }

            property JsonObject dock

            dock: JsonObject {
                property bool enabled: false
            }

            // word suggestions while typing in any app (see services/Autocomplete.qml)
            property JsonObject autocomplete

            autocomplete: JsonObject {
                property bool enabled: false
                // letters typed before suggestions show
                property int minChars: 2
                property int maxSuggestions: 5
                // put a space after a completed word
                property bool addSpace: false
                // "pointer": under the mouse; "caret": next to the text cursor;
                // "window": bottom corner of the focused window
                property string position: "pointer"
                // rank words you complete often first
                property bool learn: true
                // window classes to stay out of, comma separated (terminals by default)
                property string excludeApps: "kitty, foot, alacritty, ghostty, wezterm, konsole, terminal, terminator, tilix, ptyxis, kgx, st-256color"
            }

            property JsonObject display

            display: JsonObject {
                // screen filter through hyprsunset: colour temperature (K) and brightness (%)
                property bool nightLight: true
                property int nightLightTemperature: 5500
                property int nightLightGamma: 80
            }

            // monitor name -> { mode: "1920x1080@60.00Hz", scale: 1 }, applied when the shell starts.
            // Kept at the top level: a plain-object property nested inside a JsonObject
            // crashes Quickshell when the file is read back.
            property var monitors: ({
            })
            // kept at the top level for the same reason as `monitors`
            property var recentColors: []
            // the widgets on the desktop: [{ id, type, x, y (0-1 of the screen), scale, style }], see services/DesktopWidgets.qml
            property var widgetItems: []

            property JsonObject bar

            bar: JsonObject {
                property bool clock24h: false
                // small live bars of the sound that plays, above the tray icons (modules/Bar/BarWaves.qml)
                property bool waves: false
                // how far the bars swell across the bar (px) and how many there are
                property int wavesWidth: 30
                property int wavesBars: 12
                // tray icons shown in the bar before the rest fold behind the arrow
                property int trayVisible: 2
                // ids of tray apps that never show in the bar, separated by "|"
                property string trayHidden: ""
            }

            property JsonObject notifications

            notifications: JsonObject {
                property bool dnd: false
                // how long a toast stays when the app does not ask for a time
                property int popupSeconds: 5
            }

            property JsonObject idle

            idle: JsonObject {
                property bool enabled: true
                property int lockAfterMinutes: 5
                property int screenOffAfterMinutes: 10
            }

            // the shell as the polkit agent (modules/Polkit); off lets another agent take the job
            property JsonObject polkit

            polkit: JsonObject {
                property bool enabled: true
            }

            // the open/save dialogs of other apps drawn by the shell (modules/FileChooser, xdg-desktop-portal)
            property JsonObject fileChooser

            fileChooser: JsonObject {
                property bool enabled: true
                // tiles with big pictures instead of rows
                property bool grid: false
                // name, size, time or type; newest/biggest/Z-A first when reversed
                property string sortBy: "name"
                property bool sortReversed: false
            }

            // widgets on the desktop (modules/Widgets): clock, audio waves, calendar
            property JsonObject widgets

            widgets: JsonObject {
                property bool enabled: true
            }

            property var keyboard: ({
                "layouts": {
                }
            })
            // Hyprland options changed in Settings (see services/HyprSettings.qml):
            // "values" maps an option name ("general:gaps_in") to the value written
            property var hyprland: ({
                "enabled": true,
                "accentBorder": true,
                "blurLayers": true,
                "values": {
                }
            })
            // web search: browser command, the bang used for plain queries, extra bangs
            property var search: ({
                "browser": "helium-browser",
                "browserClass": "helium",
                "privateFlag": "--incognito",
                "defaultBang": "g",
                // where launcher results come from; a missing key means on
                "sources": {
                    "apps": true,
                    "settings": true,
                    "hyprland": true,
                    "files": true,
                    "web": true
                },
                // apps that offer results (search providers), by id: false = switched off
                "providers": {
                },
                // how files are looked up: { roots, ignore, hidden, depth, limit }; missing = the defaults
                "files": {
                },
                // the order of the groups of results (drag to sort in Settings → Launcher)
                "order": [],
                // scripts that print result rows, added in Settings → Launcher
                "commandSources": [],
                "bangs": {
                }
            })
            // clipboard menu: paste the picked item right away, or only copy it
            property var clipboard: ({
                "autoPaste": true
            })
            // the shell's own apps (apps/<App>/app.json) that are switched off, by id
            property var apps: ({
                "disabled": []
            })
        }

    }

    // one write for a burst of changes (dragging a slider)
    Timer {
        id: saveTimer

        interval: 400
        onTriggered: root.saveOverrides()
    }

    Timer {
        id: readyTimer

        interval: 300
        onTriggered: root.ready = true
    }

}
