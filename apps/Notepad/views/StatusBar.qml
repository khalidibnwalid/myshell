import "../../../components"
import "../../../config"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The line under the note: the last thing that happened, or the word and character counts.
RowLayout {
    id: root

    property bool hasNote: false
    property int words: 0
    property int characters: 0
    property string path: ""

    Layout.fillWidth: true
    Layout.leftMargin: 6
    spacing: 4

    StyledText {
        Layout.fillWidth: true
        visible: root.hasNote
        text: Notes.status !== "" ? Notes.status : root.words + (root.words === 1 ? " word" : " words") + "  ·  " + root.characters + " characters" + (root.path !== "" ? "  ·  " + Notes.baseName(root.path) : "")
        elide: Text.ElideRight
        font.pixelSize: 12
        color: Appearance.mutedColor
    }

}
