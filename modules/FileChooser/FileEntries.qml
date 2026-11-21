import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts

// The files of the folder that is open: rows or tiles in one surface tile. It owns the keyboard of the list
// (arrows, Home/End/PageUp/PageDown, Enter) and shows pictures as thumbnails; what the user did is reported by
// signals, the dialog decides what it means.
Rectangle {
    id: root

    // [{ name, path, dir, size }]
    property var entries: []
    // paths that are marked
    property var selected: []
    property bool grid: false
    // extensions that have a thumbnail (formats Qt can decode here)
    property var thumbExts: []
    property string emptyText: "This folder is empty"
    // a search is active: Escape clears it before it cancels the dialog
    property bool searching: false
    // how the entries are sorted (name, size, time) and the click on a column title that changes it
    property string sortBy: "name"
    property bool sortReversed: false
    readonly property Item activeView: grid ? gridView : list

    // Escape while a search is active: the dialog clears it
    signal clearSearchRequested()
    // a click, or the keyboard moving to a row (mods = 0)
    signal entryClicked(string path, bool isDir, int mods)
    // double click or Enter on a row
    signal entryActivated(string path, bool isDir)
    // Enter with no row current
    signal acceptRequested()
    // Up on the first row
    signal topReached()
    signal sortRequested(string key)

    function focusView() {
        activeView.forceActiveFocus();
    }

    function focusIndex(index) {
        if (entries.length === 0)
            return;
        focusView();
        activeView.currentIndex = Math.max(0, Math.min(index, entries.length - 1));
    }

    function resetCurrent() {
        list.currentIndex = -1;
        gridView.currentIndex = -1;
    }

    function isImage(name) {
        const ext = name.indexOf(".") >= 0 ? name.split(".").pop().toLowerCase() : "";
        return thumbExts.indexOf(ext) >= 0;
    }

    function iconFor(name) {
        const ext = name.indexOf(".") >= 0 ? name.split(".").pop().toLowerCase() : "";
        if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "avif", "heic", "tif", "tiff"].indexOf(ext) >= 0)
            return "image";
        if (["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac"].indexOf(ext) >= 0)
            return "music_note";
        if (["mp4", "mkv", "webm", "mov", "avi"].indexOf(ext) >= 0)
            return "movie";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].indexOf(ext) >= 0)
            return "folder_zip";
        return ["pdf", "doc", "docx", "odt", "txt", "md"].indexOf(ext) >= 0 ? "description" : "draft";
    }

    function sizeText(bytes) {
        if (bytes < 1024)
            return bytes + " B";
        const units = ["KB", "MB", "GB", "TB"];
        let v = bytes / 1024, i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (v < 10 ? v.toFixed(1) : Math.round(v)) + " " + units[i];
    }

    // the keyboard moved to a row or tile: it is the one the user means
    function keyboardPicked(view) {
        const e = entries[view.currentIndex];
        if (e && view.activeFocus)
            entryClicked(e.path, e.dir, 0);
    }

    function escapePressed(event) {
        event.accepted = searching;
        if (searching)
            clearSearchRequested();
    }

    function enterCurrent() {
        const e = entries[activeView.currentIndex];
        if (e)
            entryActivated(e.path, e.dir);
        else
            acceptRequested();
    }

    Layout.fillWidth: true
    Layout.preferredHeight: 340
    radius: 20
    color: Appearance.surfaceColor
    clip: true

    // column titles of the list: click one to sort by it, click it again to reverse
    RowLayout {
        id: columns

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        height: 28
        visible: !root.grid
        spacing: 12

        // the picture column
        Item {
            implicitWidth: 32
        }

        FileColumnTitle {
            Layout.fillWidth: true
            label: "Name"
            key: "name"
            sortBy: root.sortBy
            sortReversed: root.sortReversed
            onClicked: root.sortRequested(key)
        }

        FileColumnTitle {
            Layout.preferredWidth: 64
            label: "Size"
            key: "size"
            sortBy: root.sortBy
            sortReversed: root.sortReversed
            onClicked: root.sortRequested(key)
            alignRight: true
        }

        FileColumnTitle {
            Layout.preferredWidth: 96
            label: "Modified"
            key: "time"
            sortBy: root.sortBy
            sortReversed: root.sortReversed
            onClicked: root.sortRequested(key)
            alignRight: true
        }
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.topMargin: 36
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.bottomMargin: 6
        visible: !root.grid
        model: root.entries
        currentIndex: -1
        clip: true
        activeFocusOnTab: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        Accessible.role: Accessible.List
        Accessible.name: "Files"
        onCurrentIndexChanged: root.keyboardPicked(list)
        Keys.onShortcutOverride: event => nav.override(event)
        Keys.onPressed: event => nav.press(event)
        Keys.onEscapePressed: event => root.escapePressed(event)

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool picked: root.selected.indexOf(modelData.path) >= 0

            width: ListView.view.width
            height: 46
            radius: 14
            color: picked ? Qt.alpha(Appearance.accentColor, 0.22) : (rowArea.containsMouse ? Appearance.surfaceHighColor : "transparent")
            Accessible.role: Accessible.ListItem
            Accessible.name: (modelData.dir ? "Folder " : "File ") + modelData.name
            Accessible.selected: picked

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                FileThumb {
                    size: 32
                    path: row.modelData.path
                    dir: row.modelData.dir
                    icon: root.iconFor(row.modelData.name)
                    image: root.isImage(row.modelData.name)
                }

                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    elide: Text.ElideMiddle
                    font.pixelSize: 13
                }

                StyledText {
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.dir ? "" : root.sizeText(row.modelData.size)
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                }

                StyledText {
                    Layout.preferredWidth: 96
                    horizontalAlignment: Text.AlignRight
                    text: Qt.formatDateTime(row.modelData.modified, "d MMM yyyy")
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                }
            }

            FocusRing {
                gap: 0
                radius: 14
                ringColor: Appearance.fgColor
                visible: row.ListView.isCurrentItem && list.activeFocus
            }

            MouseArea {
                id: rowArea

                anchors.fill: parent
                hoverEnabled: true
                onClicked: mouse => {
                    list.forceActiveFocus();
                    list.currentIndex = row.index;
                    root.entryClicked(row.modelData.path, row.modelData.dir, mouse.modifiers);
                }
                onDoubleClicked: root.entryActivated(row.modelData.path, row.modelData.dir)
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.entries.length === 0
            text: root.emptyText
            color: Appearance.mutedColor
            font.pixelSize: 13
        }
    }

    // the same files as tiles with bigger pictures
    GridView {
        id: gridView

        anchors.fill: parent
        anchors.margins: 6
        visible: root.grid
        model: root.entries
        currentIndex: -1
        clip: true
        activeFocusOnTab: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        // whole columns that fill the width
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 128)))
        cellHeight: 134
        Accessible.role: Accessible.List
        Accessible.name: "Files"
        onCurrentIndexChanged: root.keyboardPicked(gridView)
        Keys.onShortcutOverride: event => nav.override(event)
        Keys.onPressed: event => nav.press(event)
        Keys.onEscapePressed: event => root.escapePressed(event)

        delegate: Item {
            id: tile

            required property var modelData
            required property int index
            readonly property bool picked: root.selected.indexOf(modelData.path) >= 0

            width: gridView.cellWidth
            height: gridView.cellHeight
            Accessible.role: Accessible.ListItem
            Accessible.name: (modelData.dir ? "Folder " : "File ") + modelData.name
            Accessible.selected: picked

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 18
                color: tile.picked ? Qt.alpha(Appearance.accentColor, 0.22) : (tileArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

                FileThumb {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    size: 74
                    path: tile.modelData.path
                    dir: tile.modelData.dir
                    icon: root.iconFor(tile.modelData.name)
                    image: root.isImage(tile.modelData.name)
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.modelData.name
                    elide: Text.ElideMiddle
                    font.pixelSize: 12
                }

                FocusRing {
                    gap: 0
                    radius: 18
                    ringColor: Appearance.fgColor
                    visible: tile.GridView.isCurrentItem && gridView.activeFocus
                }

                MouseArea {
                    id: tileArea

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: mouse => {
                        gridView.forceActiveFocus();
                        gridView.currentIndex = tile.index;
                        root.entryClicked(tile.modelData.path, tile.modelData.dir, mouse.modifiers);
                    }
                    onDoubleClicked: root.entryActivated(tile.modelData.path, tile.modelData.dir)
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.entries.length === 0
            text: root.emptyText
            color: Appearance.mutedColor
            font.pixelSize: 13
        }
    }

    // Home/End/PageUp/PageDown/Enter for whichever view is shown; Up on the first row goes to the search box
    ListNav {
        id: nav

        view: root.activeView
        rowHeight: 46
        horizontal: root.grid
        onActivated: root.enterCurrent()
        onTopReached: root.topReached()
    }
}
