import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    readonly property alias appearance: jsonAdapter.appearance
    readonly property alias layout: jsonAdapter.layout
    readonly property alias keyboard: jsonAdapter.keyboard
    readonly property alias search: jsonAdapter.search
    readonly property alias clipboard: jsonAdapter.clipboard
    readonly property alias capture: jsonAdapter.capture
    readonly property alias dock: jsonAdapter.dock
    readonly property alias idle: jsonAdapter.idle
    readonly property alias bar: jsonAdapter.bar
    readonly property alias notifications: jsonAdapter.notifications
    readonly property alias display: jsonAdapter.display
    readonly property alias monitors: jsonAdapter.monitors
    readonly property alias recentColors: jsonAdapter.recentColors

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

    function setMonitors(value) {
        jsonAdapter.monitors = value;
    }

    // --- where the bar is, for everything that lines up with it ---
    readonly property string barPosition: ["left", "right", "top", "bottom"].indexOf(layout.barPosition) >= 0 ? layout.barPosition : "right"
    readonly property bool barHorizontal: barPosition === "top" || barPosition === "bottom"
    // thickness of the bar
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

    FileView {
        id: file

        watchChanges: true
        // our own write must not be read back: a stale write landing late would undo a newer change
        onFileChanged: {
            if (!selfWrite.running)
                reload();
        }
        // changes made in the Settings window are written back to config.json
        onAdapterUpdated: saveTimer.restart()
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
            }

            property JsonObject dock

            dock: JsonObject {
                property bool enabled: false
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

            property JsonObject bar

            bar: JsonObject {
                property bool clock24h: false
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

            property var keyboard: ({
                "layouts": {
                }
            })
            // web search: browser command, the bang used for plain queries, extra bangs
            property var search: ({
                "browser": "helium-browser",
                "browserClass": "helium",
                "privateFlag": "--incognito",
                "defaultBang": "g",
                "bangs": {
                }
            })
            // clipboard menu: paste the picked item right away, or only copy it
            property var clipboard: ({
                "autoPaste": true
            })
        }

    }

    // one write for a burst of changes (dragging a slider)
    Timer {
        id: saveTimer

        interval: 400
        onTriggered: {
            selfWrite.restart();
            file.writeAdapter();
        }
    }

    Timer {
        id: selfWrite

        interval: 1000
    }

}
