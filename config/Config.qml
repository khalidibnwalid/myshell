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

    FileView {
        watchChanges: true
        onFileChanged: reload()
        path: Qt.resolvedUrl("../config.json")

        JsonAdapter {
            id: jsonAdapter

            property JsonObject appearance

            appearance: JsonObject {
                property string bgColor: "#131317"
                property string fgColor: "#e5e1e7"
                property string accentColor: "#c2c1ff"
                property string accentColorLight: "#E3E3FA"
                property string highlightColor: "#54545f"
                property string borderColor: "#000000"
                property real opacity: 0.5
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

}
