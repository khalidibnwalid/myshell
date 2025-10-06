pragma Singleton

import Quickshell.Io
import Quickshell

Singleton {

    readonly property alias appearance: jsonAdapter.appearance
    FileView {
        // path: "../config.json"

        watchChanges: true
        onFileChanged: reload()

        // onAdapterUpdated: writeAdapter()
        path: Qt.resolvedUrl("../config.json")

        JsonAdapter {
            id: jsonAdapter
            property JsonObject appearance: JsonObject {
                property string bgColor: "#131317"
                property string fgColor: "#e5e1e7"
                property string accentColor: "#c2c1ff"
                property string accentColorLight: "#E3E3FA"
                property string highlightColor: "#54545f"
                property string borderColor: "#000000"
            }
        }
    }
}
