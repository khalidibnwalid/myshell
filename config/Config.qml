import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    readonly property alias appearance: jsonAdapter.appearance
    readonly property alias layout: jsonAdapter.layout
    readonly property alias keyboard: jsonAdapter.keyboard
    readonly property alias search: jsonAdapter.search

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
        }

    }

}
