import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The row above the content: the title, the search box, the sort choice, opening files and closing.
RowLayout {
    id: root

    property string title: ""
    property bool sidebarOpen: true
    property bool canGoBack: false
    property bool showSort: false
    property string sortKey: "title"
    readonly property bool typing: search.inputItem.activeFocus

    signal sidebarRequested
    signal backClicked
    signal queryEdited(string text)
    signal sortSelected(string key)
    signal openRequested
    signal closeRequested

    function focusSearch() {
        search.focusInput();
    }

    function clearSearch() {
        search.clear();
    }

    Layout.fillWidth: true
    Layout.topMargin: 4
    spacing: 8

    IconButton {
        visible: !root.sidebarOpen
        icon: "left_panel_open"
        size: 34
        iconSize: 20
        onClicked: root.sidebarRequested()
    }

    IconButton {
        visible: root.canGoBack
        icon: "arrow_back"
        size: 34
        iconSize: 20
        onClicked: root.backClicked()
    }

    StyledText {
        Layout.fillWidth: true
        text: root.title
        elide: Text.ElideRight
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    FieldInput {
        id: search

        Layout.preferredWidth: 220
        icon: "search"
        placeholder: "Search"
        onEdited: text => root.queryEdited(text)
    }

    Dropdown {
        visible: root.showSort
        icon: "sort"
        popupWidth: 180
        value: root.sortKey
        model: [
            {
                "label": "Title",
                "value": "title"
            },
            {
                "label": "Artist",
                "value": "artist"
            },
            {
                "label": "Album",
                "value": "album"
            },
            {
                "label": "Recently added",
                "value": "added"
            },
            {
                "label": "Longest",
                "value": "duration"
            }
        ]
        onSelected: v => root.sortSelected(v)
    }

    IconButton {
        icon: "file_open"
        size: 34
        iconSize: 20
        onClicked: root.openRequested()
    }

    IconButton {
        icon: "close"
        size: 34
        iconSize: 20
        onClicked: root.closeRequested()
    }
}
