import "../../../components"
import "../../../config"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The row above the note: the way back to the list while it is folded, Edit / View, and the actions.
RowLayout {
    id: root

    property bool sidebarOpen: true
    property bool hasNote: false
    property string title: "Notes"
    property string mode: "edit"
    property bool pinned: false

    signal sidebarRequested
    signal modeSelected(string mode)
    signal openRequested
    signal saveRequested
    signal copyRequested
    signal pinRequested
    signal deleteRequested
    signal closeRequested

    Layout.fillWidth: true
    Layout.leftMargin: 6

    IconButton {
        visible: !root.sidebarOpen
        icon: "left_panel_open"
        size: 34
        iconSize: 20
        onClicked: root.sidebarRequested()
    }

    StyledText {
        Layout.fillWidth: true
        visible: !root.sidebarOpen
        text: root.title
        elide: Text.ElideRight
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }

    Item {
        Layout.fillWidth: true
        visible: root.sidebarOpen
    }

    Segmented {
        visible: root.hasNote
        model: [
            {
                "label": "Edit",
                "value": "edit"
            },
            {
                "label": "View",
                "value": "view"
            }
        ]
        value: root.mode
        onSelected: v => root.modeSelected(v)
    }

    IconButton {
        icon: "folder_open"
        size: 34
        iconSize: 20
        onClicked: root.openRequested()
    }

    IconButton {
        visible: root.hasNote
        icon: "save"
        size: 34
        iconSize: 20
        onClicked: root.saveRequested()
    }

    IconButton {
        visible: root.hasNote
        icon: "content_copy"
        size: 34
        iconSize: 20
        onClicked: root.copyRequested()
    }

    IconButton {
        visible: root.hasNote
        icon: "push_pin"
        size: 34
        iconSize: 20
        iconFill: root.pinned ? 1 : 0
        toggled: root.pinned
        onClicked: root.pinRequested()
    }

    IconButton {
        visible: root.hasNote
        icon: "delete"
        size: 34
        iconSize: 20
        onClicked: root.deleteRequested()
    }

    IconButton {
        icon: "close"
        size: 34
        iconSize: 20
        onClicked: root.closeRequested()
    }
}
