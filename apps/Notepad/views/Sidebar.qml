import "../../../components"
import "../../../config"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The list of notes: slides shut (the content keeps its width while it does), with a search box, and a handle on
// its right edge to drag its width.
Item {
    id: root

    property bool open: true
    // the width while it is open; the handle on the right edge changes it
    property real panelWidth: 260
    property string query: ""

    signal foldRequested
    signal widthDragged(real width)
    signal queryEdited(string text)
    signal createRequested
    signal noteOpened

    function focusSearch() {
        search.focusInput();
    }

    function clearSearch() {
        search.clear();
    }

    Layout.fillWidth: false
    Layout.fillHeight: true
    Layout.preferredWidth: root.open ? root.panelWidth : 0
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    visible: Layout.preferredWidth > 0
    clip: true

    Behavior on Layout.preferredWidth {
        // no slide while the handle is dragged, so the edge follows the pointer
        enabled: !grip.pressed

        NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.OutCubic
        }
    }

ColumnLayout {
    x: 12
    y: 12
    width: root.panelWidth - 24
    height: parent.height - 24
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.topMargin: 10

        StyledText {
            Layout.fillWidth: true
            text: "Notes"
            font.pixelSize: 18
            font.weight: Font.Bold
        }

        IconButton {
            icon: "left_panel_close"
            size: 34
            iconSize: 20
            onClicked: root.foldRequested()
        }

        IconButton {
            icon: "add"
            size: 34
            onClicked: root.createRequested()
        }
    }

    FieldInput {
        id: search

        Layout.fillWidth: true
        placeholder: "Search notes"
        icon: "search"
        onEdited: text => root.queryEdited(text)
    }

NoteList {
    Layout.fillWidth: true
    Layout.fillHeight: true
    query: root.query
    onNoteOpened: root.noteOpened()
}
}

    // drag to change the width of the list
    MouseArea {
        id: grip

        property real startX: 0
        property real startWidth: 0

        anchors.right: parent.right
        width: 10
        height: parent.height
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        onPressed: mouse => {
            startX = mapToItem(null, mouse.x, 0).x;
            startWidth = root.panelWidth;
        }
        onPositionChanged: mouse => {
            if (!pressed || !root.open)
                return;
            const w = startWidth + mapToItem(null, mouse.x, 0).x - startX;
            // dragged well below the narrowest width: fold it away instead
            if (w < 120)
                root.foldRequested();
            else
                root.widthDragged(Math.max(180, Math.min(480, w)));
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 48
            radius: 1.5
            color: Appearance.accentColor
            opacity: grip.pressed ? 0.9 : (grip.containsMouse ? 0.5 : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animFast
                }
            }
        }
    }
}
