import "../../../components"
import "../../../config"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The note itself: written in a text area, or shown as Markdown; a hint when no note is open.
Rectangle {
    id: root

    // the note that is open (or null), its text, and "edit" or "view"
    property var current: null
    property string noteText: ""
    property string mode: "edit"

    function focusEditor() {
        editor.forceActiveFocus();
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 20
    color: Appearance.surfaceColor

    ScrollView {
        anchors.fill: parent
        anchors.margins: 6
        visible: root.current !== null && root.mode === "edit"

        TextArea {
            id: editor

            // the note changes when another is picked; typing is sent back as it comes
            property string noteId: root.current ? root.current.id : ""

            function load() {
                const text = root.current ? root.current.text : "";
                if (editor.text !== text)
                    editor.text = text;
            }

            onNoteIdChanged: load()
            Component.onCompleted: load()

            // text that changed without typing (a file opened into the note)
            Connections {
                function onNotesChanged() {
                    if (!editor.activeFocus)
                        editor.load();
                }

                target: Notes
            }
            onTextChanged: {
                if (activeFocus && noteId !== "")
                    Notes.setText(noteId, text);
            }
            wrapMode: TextEdit.Wrap
            placeholderText: "Write something…"
            placeholderTextColor: Appearance.mutedColor
            color: Appearance.fgColor
            selectionColor: Appearance.accentColor
            selectedTextColor: Appearance.accentContrastColor
            font.family: Appearance.fontFamily
            font.pixelSize: 15
            leftPadding: 16
            rightPadding: 16
            topPadding: 14
            bottomPadding: 14
            background: null
        }
    }

    // the note as Markdown
    ScrollView {
        id: viewer

        anchors.fill: parent
        anchors.margins: 6
        visible: root.current !== null && root.mode === "view"
        contentWidth: availableWidth

        Text {
            width: viewer.availableWidth
            padding: 16
            text: root.noteText.trim() === "" ? "Nothing to show yet" : root.noteText
            textFormat: root.noteText.trim() === "" ? Text.PlainText : Text.MarkdownText
            wrapMode: Text.Wrap
            color: root.noteText.trim() === "" ? Appearance.mutedColor : Appearance.fgColor
            linkColor: Appearance.accentColor
            font.family: Appearance.fontFamily
            font.pixelSize: 15
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.current === null
        text: "Press + to write a note"
        color: Appearance.mutedColor
    }
}
