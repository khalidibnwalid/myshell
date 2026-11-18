import "../../components"
import "../../config"
import "../../services/"
import "components"
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The audio player in its own window: the library by tracks, albums and artists, favourites and history,
// a queue that can be dragged into order, synced lyrics and the controls. The sound is made by Player,
// so it goes on when the window is closed.
// bind = $mainMod, M, global, quickshell:audio
ApplicationWindow {
    id: root

    readonly property var sections: [
        {
            "id": "tracks",
            "label": "Tracks",
            "icon": "music_note",
            "count": Library.tracks.length
        },
        {
            "id": "albums",
            "label": "Albums",
            "icon": "album",
            "count": Library.albums.length
        },
        {
            "id": "artists",
            "label": "Artists",
            "icon": "person",
            "count": Library.artists.length
        },
        {
            "id": "favorites",
            "label": "Favourites",
            "icon": "favorite",
            "count": Library.favoriteCount
        },
        {
            "id": "recent",
            "label": "Recently played",
            "icon": "history",
            "count": Library.history.length
        }
    ]
    property string section: "tracks"
    // an album or an artist that is open: { kind: "album" | "artist", key }
    property var detail: null
    property string query: ""
    property string sortKey: "title"
    property bool sidebarOpen: true
    // the pane on the right: "" (folded), "lyrics" or "queue"
    property string pane: ""
    readonly property var detailItem: {
        if (!detail)
            return null;
        const list = detail.kind === "album" ? Library.albums : Library.artists;
        return list.find(a => a.key === detail.key) ?? null;
    }
    readonly property var shownTracks: {
        if (detailItem)
            return Library.filter(detailItem.tracks, query);
        if (section === "tracks")
            return Library.sorted(Library.filter(Library.tracks, query), sortKey);
        if (section === "favorites")
            return Library.sorted(Library.filter(Library.tracks.filter(t => Library.favorites[t.path] === true), query), sortKey);
        if (section === "recent")
            return Library.filter(Library.history.map(p => Library.byPath[p]).filter(t => t !== undefined), query);
        return [];
    }
    readonly property var shownAlbums: {
        const words = query.toLowerCase().split(/\s+/).filter(w => w !== "");
        return Library.albums.filter(a => words.every(w => (a.title + " " + a.artist).toLowerCase().includes(w)));
    }
    readonly property var shownArtists: {
        const q = query.trim().toLowerCase();
        return Library.artists.filter(a => a.name.toLowerCase().includes(q));
    }
    readonly property string viewKind: detailItem ? "tracks" : (section === "albums" ? "albums" : (section === "artists" ? "artists" : "tracks"))
    readonly property var sectionInfo: sections.find(s => s.id === section)

    function openWindow() {
        WindowManager.openAudio();
    }

    function go(id) {
        section = id;
        detail = null;
        query = "";
        search.clear();
    }

    function playShown(i) {
        Player.playList(shownTracks.map(t => t.path), i);
    }

    function togglePane(which) {
        pane = pane === which ? "" : which;
    }

    width: 1100
    height: 720
    minimumWidth: 900
    minimumHeight: 520
    title: "Audio"
    visible: WindowManager.audioVisible
    color: Qt.alpha(Appearance.bgColor, Appearance.isLight ? 1 - Math.pow(1 - Config.appearance.settingsOpacity, 2) : Config.appearance.settingsOpacity)
    onClosing: WindowManager.audioVisible = false
    onVisibleChanged: {
        if (visible)
            Library.refresh();
    }
    // the library and the saved queue are read from the start of the shell
    Component.onCompleted: {
        Library.load();
        Player.load();
    }

    Connections {
        function onAudioRaiseRequested() {
            root.raise();
            root.requestActivate();
        }

        target: WindowManager
    }

    GlobalShortcut {
        name: "audio"
        onPressed: WindowManager.audioVisible = !WindowManager.audioVisible
    }

    GlobalShortcut {
        name: "audioPlayPause"
        onPressed: Player.toggle()
    }

    GlobalShortcut {
        name: "audioNext"
        onPressed: Player.next()
    }

    GlobalShortcut {
        name: "audioPrevious"
        onPressed: Player.previous()
    }

    // qs ipc call audio toggle | open | close | playpause | play | pause | next | previous | stop
    //                        | openFile <path> | enqueue <path> | volume <0-100> | status
    IpcHandler {
        function toggle(): void {
            if (WindowManager.audioVisible)
                WindowManager.audioVisible = false;
            else
                root.openWindow();
        }

        function open(): void {
            root.openWindow();
        }

        function close(): void {
            WindowManager.audioVisible = false;
        }

        function playpause(): void {
            Player.toggle();
        }

        function play(): void {
            Player.play();
        }

        function pause(): void {
            Player.pause();
        }

        function stop(): void {
            Player.stop();
        }

        function next(): void {
            Player.next();
        }

        function previous(): void {
            Player.previous();
        }

        function openFile(path: string): void {
            Player.openPaths([path], false);
            root.openWindow();
        }

        function enqueue(path: string): void {
            Player.openPaths([path], true);
        }

        function volume(percent: int): void {
            Player.setVolume(percent / 100);
        }

        function status(): string {
            const t = Player.track;
            if (!t)
                return "Nothing is playing";
            return (Player.playing ? "Playing" : "Paused") + ": " + (t.artist ? t.artist + " - " : "") + t.title + " (" + Library.format(Player.positionMs / 1000) + "/" + Library.format(Player.durationMs / 1000) + ")";
        }

        target: "audio"
    }

    FileDialog {
        id: openDialog

        title: "Open audio"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Audio and video (*.mp3 *.flac *.ogg *.opus *.m4a *.aac *.wav *.wma *.mka *.mp4 *.mkv *.webm)", "All files (*)"]
        onAccepted: Player.openPaths(selectedFiles.map(f => f.toString()), false)
    }

    FolderDialog {
        id: folderDialog

        title: "Add an audio folder"
        onAccepted: Library.addFolder(selectedFolder.toString())
    }

    Shortcut {
        sequence: "Space"
        enabled: !search.inputItem.activeFocus
        onActivated: Player.toggle()
    }

    Shortcut {
        sequence: "Left"
        enabled: !search.inputItem.activeFocus
        onActivated: Player.seek(Player.positionMs - 5000)
    }

    Shortcut {
        sequence: "Right"
        enabled: !search.inputItem.activeFocus
        onActivated: Player.seek(Player.positionMs + 5000)
    }

    Shortcut {
        sequence: "Up"
        enabled: !search.inputItem.activeFocus
        onActivated: Player.setVolume(Player.volume + 0.05)
    }

    Shortcut {
        sequence: "Down"
        enabled: !search.inputItem.activeFocus
        onActivated: Player.setVolume(Player.volume - 0.05)
    }

    Shortcut {
        sequence: "Ctrl+Right"
        onActivated: Player.next()
    }

    Shortcut {
        sequence: "Ctrl+Left"
        onActivated: Player.previous()
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: {
            if (!root.sidebarOpen)
                root.sidebarOpen = true;
            search.focusInput();
        }
    }

    Shortcut {
        sequence: "Ctrl+B"
        onActivated: root.sidebarOpen = !root.sidebarOpen
    }

    Shortcut {
        sequence: "Ctrl+L"
        onActivated: root.togglePane("lyrics")
    }

    Shortcut {
        sequence: "Ctrl+J"
        onActivated: root.togglePane("queue")
    }

    Shortcut {
        sequence: "Ctrl+O"
        onActivated: openDialog.open()
    }

    Shortcut {
        sequence: "Ctrl+Shift+S"
        onActivated: Player.setShuffle(!Player.shuffle)
    }

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: Player.cycleRepeat()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.query !== "") {
                search.clear();
                root.query = "";
            } else if (root.detail) {
                root.detail = null;
            } else {
                WindowManager.audioVisible = false;
            }
        }
    }

    DropArea {
        id: drop

        anchors.fill: parent
        onDropped: event => {
            if (event.urls.length > 0)
                Player.openPaths(event.urls.map(u => u.toString()), false);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // the sections
                Item {
                    Layout.fillHeight: true
                    Layout.preferredWidth: root.sidebarOpen ? 210 : 0
                    Layout.minimumWidth: Layout.preferredWidth
                    Layout.maximumWidth: Layout.preferredWidth
                    clip: true

                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: Appearance.animNormal
                            easing.type: Easing.OutCubic
                        }
                    }

                    ColumnLayout {
                        width: 210
                        height: parent.height
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.bottomMargin: 8
                            Layout.topMargin: 4

                            MaterialSymbol {
                                icon: "graphic_eq"
                                fill: 1
                                font.pixelSize: 24
                                color: Appearance.accentColor
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "Audio"
                                font.pixelSize: 20
                                font.weight: Font.Bold
                            }

                            IconButton {
                                icon: "left_panel_close"
                                size: 34
                                iconSize: 20
                                onClicked: root.sidebarOpen = false
                            }
                        }

                        Repeater {
                            model: root.sections

                            delegate: Rectangle {
                                id: nav

                                required property var modelData
                                readonly property bool current: root.section === modelData.id

                                Layout.fillWidth: true
                                implicitHeight: 42
                                radius: 14
                                color: current ? Appearance.accentColor : (navArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    MaterialSymbol {
                                        icon: nav.modelData.icon
                                        fill: nav.current ? 1 : 0
                                        font.pixelSize: 20
                                        color: nav.current ? Appearance.accentContrastColor : Appearance.fgColor
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: nav.modelData.label
                                        elide: Text.ElideRight
                                        font.weight: Font.Medium
                                        color: nav.current ? Appearance.accentContrastColor : Appearance.fgColor
                                    }

                                    StyledText {
                                        text: nav.modelData.count
                                        font.pixelSize: 12
                                        color: nav.current ? Appearance.accentContrastColor : Appearance.mutedColor
                                    }
                                }

                                MouseArea {
                                    id: navArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.go(nav.modelData.id)
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 42
                            radius: 14
                            color: foldersArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                MaterialSymbol {
                                    icon: "create_new_folder"
                                    font.pixelSize: 20
                                    color: Appearance.mutedColor
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Library.scanning ? "Indexing…" : "Folders"
                                    color: Appearance.mutedColor
                                }

                                MaterialSymbol {
                                    visible: Library.scanning
                                    icon: "sync"
                                    font.pixelSize: 18
                                    color: Appearance.accentColor

                                    RotationAnimator on rotation {
                                        running: Library.scanning
                                        from: 0
                                        to: 360
                                        duration: 1200
                                        loops: Animation.Infinite
                                    }
                                }
                            }

                            MouseArea {
                                id: foldersArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: foldersPopup.open()
                            }
                        }

                        StyledText {
                            Layout.leftMargin: 14
                            Layout.bottomMargin: 6
                            text: Library.tracks.length + " tracks · " + Library.total(Library.tracks)
                            font.pixelSize: 12
                            color: Appearance.mutedColor
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8

                        IconButton {
                            visible: !root.sidebarOpen
                            icon: "left_panel_open"
                            size: 34
                            iconSize: 20
                            onClicked: root.sidebarOpen = true
                        }

                        IconButton {
                            visible: root.detail !== null
                            icon: "arrow_back"
                            size: 34
                            iconSize: 20
                            onClicked: root.detail = null
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.detailItem ? (root.detail.kind === "album" ? root.detailItem.title : root.detailItem.name) : root.sectionInfo.label
                            elide: Text.ElideRight
                            font.pixelSize: 20
                            font.weight: Font.Bold
                        }

                        FieldInput {
                            id: search

                            Layout.preferredWidth: 220
                            icon: "search"
                            placeholder: "Search"
                            onEdited: text => root.query = text
                        }

                        Dropdown {
                            visible: root.viewKind === "tracks" && !root.detailItem && root.section !== "recent"
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
                            onSelected: v => root.sortKey = v
                        }

                        IconButton {
                            icon: "file_open"
                            size: 34
                            iconSize: 20
                            onClicked: openDialog.open()
                        }

                        IconButton {
                            icon: "close"
                            size: 34
                            iconSize: 20
                            onClicked: WindowManager.audioVisible = false
                        }
                    }

                    // the header of an open album or artist
                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.detailItem !== null
                        implicitHeight: 112
                        radius: 20
                        color: Appearance.surfaceColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 16

                            Cover {
                                Layout.preferredWidth: 84
                                Layout.preferredHeight: 84
                                radius: root.detail && root.detail.kind === "artist" ? 42 : 14
                                source: root.detailItem ? root.detailItem.cover : ""
                                icon: root.detail && root.detail.kind === "artist" ? "person" : "album"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.detailItem ? (root.detail.kind === "album" ? root.detailItem.title : root.detailItem.name) : ""
                                    elide: Text.ElideRight
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        if (!root.detailItem)
                                            return "";
                                        const it = root.detailItem;
                                        const n = it.tracks.length + (it.tracks.length === 1 ? " track" : " tracks");
                                        if (root.detail.kind === "album")
                                            return [it.artist, it.year, n, Library.total(it.tracks)].filter(x => x).join(" · ");
                                        return [n, it.albumCount + (it.albumCount === 1 ? " album" : " albums"), Library.total(it.tracks)].join(" · ");
                                    }
                                    elide: Text.ElideRight
                                    color: Appearance.mutedColor
                                }

                                RowLayout {
                                    Layout.topMargin: 8
                                    spacing: 8

                                    PillButton {
                                        text: "Play"
                                        icon: "play_arrow"
                                        toggled: true
                                        onClicked: {
                                            Player.shuffle = false;
                                            root.playShown(0);
                                        }
                                    }

                                    PillButton {
                                        text: "Shuffle"
                                        icon: "shuffle"
                                        onClicked: Player.playShuffled(root.shownTracks.map(t => t.path))
                                    }
                                }
                            }
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.viewKind === "tracks" ? 0 : (root.viewKind === "albums" ? 1 : 2)

                        ColumnLayout {
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                visible: !root.detailItem && root.shownTracks.length > 0
                                spacing: 8

                                PillButton {
                                    text: "Play all"
                                    icon: "play_arrow"
                                    onClicked: {
                                        Player.shuffle = false;
                                        root.playShown(0);
                                    }
                                }

                                PillButton {
                                    text: "Shuffle"
                                    icon: "shuffle"
                                    onClicked: Player.playShuffled(root.shownTracks.map(t => t.path))
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.shownTracks.length + " tracks · " + Library.total(root.shownTracks)
                                    color: Appearance.mutedColor
                                    font.pixelSize: 13
                                }

                                PillButton {
                                    visible: root.section === "recent"
                                    text: "Clear"
                                    icon: "delete"
                                    onClicked: Library.clearHistory()
                                }
                            }

                            TrackList {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                tracks: root.shownTracks
                                numbered: root.detail !== null && root.detail.kind === "album"
                                showAlbum: !(root.detail !== null && root.detail.kind === "album")
                                emptyIcon: root.query !== "" ? "search_off" : root.sectionInfo.icon
                                emptyText: root.query !== "" ? "Nothing found" : (root.section === "favorites" ? "No favourites yet" : (root.section === "recent" ? "Nothing played yet" : (Library.scanning ? "Indexing your audio…" : "No audio found")))
                                emptyHint: root.query !== "" ? "" : (root.section === "favorites" ? "Press the heart on a track" : (root.section === "tracks" && !Library.scanning ? "Add a folder, or drop files here" : ""))
                                onActivated: i => root.playShown(i)
                            }
                        }

                        GridView {
                            id: grid

                            readonly property int columns: Math.max(2, Math.floor(width / 176))

                            clip: true
                            model: root.shownAlbums
                            cellWidth: Math.floor(width / columns)
                            cellHeight: cellWidth + 56
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Item {
                                id: card

                                required property var modelData

                                width: grid.cellWidth
                                height: grid.cellHeight

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: 18
                                    color: cardArea.containsMouse ? Appearance.surfaceColor : "transparent"

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Cover {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: width
                                            radius: 12
                                            source: card.modelData.cover
                                            icon: "album"

                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                anchors.margins: 8
                                                width: 40
                                                height: 40
                                                radius: 20
                                                color: Appearance.accentColor
                                                opacity: cardArea.containsMouse ? 1 : 0
                                                scale: cardArea.containsMouse ? 1 : 0.8

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: Appearance.animFast
                                                    }
                                                }

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: Appearance.animFast
                                                    }
                                                }

                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    icon: "play_arrow"
                                                    fill: 1
                                                    font.pixelSize: 24
                                                    color: Appearance.accentContrastColor
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        Player.shuffle = false;
                                                        Player.playList(card.modelData.tracks.map(t => t.path), 0);
                                                    }
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: card.modelData.title
                                                elide: Text.ElideRight
                                                font.weight: Font.Medium
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: card.modelData.artist || (card.modelData.tracks.length + " tracks")
                                                elide: Text.ElideRight
                                                font.pixelSize: 12
                                                color: Appearance.mutedColor
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: cardArea

                                        z: -1
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.detail = {
                                            "kind": "album",
                                            "key": card.modelData.key
                                        }
                                    }
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                visible: root.shownAlbums.length === 0
                                text: "No albums"
                                color: Appearance.mutedColor
                            }
                        }

                        ListView {
                            id: artistList

                            clip: true
                            spacing: 2
                            model: root.shownArtists
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Rectangle {
                                id: artistRow

                                required property var modelData

                                width: artistList.width - (artistList.ScrollBar.vertical.visible ? 10 : 0)
                                height: 64
                                radius: 14
                                color: artistArea.containsMouse ? Appearance.surfaceColor : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 14
                                    spacing: 14

                                    Cover {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        radius: 24
                                        source: artistRow.modelData.cover
                                        icon: "person"
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: artistRow.modelData.name
                                            elide: Text.ElideRight
                                            font.weight: Font.Medium
                                        }

                                        StyledText {
                                            text: artistRow.modelData.tracks.length + " tracks · " + artistRow.modelData.albumCount + (artistRow.modelData.albumCount === 1 ? " album" : " albums")
                                            font.pixelSize: 12
                                            color: Appearance.mutedColor
                                        }
                                    }

                                    MaterialSymbol {
                                        icon: "chevron_right"
                                        font.pixelSize: 20
                                        color: Appearance.mutedColor
                                    }
                                }

                                MouseArea {
                                    id: artistArea

                                    z: -1
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.detail = {
                                        "kind": "artist",
                                        "key": artistRow.modelData.key
                                    }
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                visible: root.shownArtists.length === 0
                                text: "No artists"
                                color: Appearance.mutedColor
                            }
                        }
                    }
                }
        // lyrics and the queue
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: root.pane !== "" ? 340 : 0
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Appearance.animNormal
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                width: 340
                height: parent.height
                radius: 24
                color: Appearance.surfaceColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Segmented {
                        Layout.alignment: Qt.AlignHCenter
                        value: root.pane
                        model: [
                            {
                                "label": "Lyrics",
                                "value": "lyrics"
                            },
                            {
                                "label": "Queue",
                                "value": "queue"
                            }
                        ]
                        onSelected: v => root.pane = v
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.pane === "queue" ? 1 : 0

                        // lyrics, or the cover when there are none
                        Item {
                            ListView {
                                id: lyricsView

                                anchors.fill: parent
                                visible: Player.lyrics.length > 0
                                clip: true
                                model: Player.lyrics
                                currentIndex: Player.lyricsSynced ? Math.max(0, Player.lyricIndex) : 0
                                highlightRangeMode: Player.lyricsSynced ? ListView.ApplyRange : ListView.NoHighlightRange
                                preferredHighlightBegin: height / 2 - 30
                                preferredHighlightEnd: height / 2 + 30
                                highlightMoveDuration: 380
                                highlightFollowsCurrentItem: true
                                boundsBehavior: Flickable.StopAtBounds
                                header: Item {
                                    height: Player.lyricsSynced ? lyricsView.height / 2 - 30 : 4
                                }
                                footer: Item {
                                    height: Player.lyricsSynced ? lyricsView.height / 2 : 4
                                }

                                delegate: Item {
                                    id: line

                                    required property var modelData
                                    required property int index
                                    readonly property bool current: Player.lyricsSynced && index === Player.lyricIndex

                                    width: lyricsView.width
                                    height: text.implicitHeight + 14

                                    StyledText {
                                        id: text

                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 8
                                        text: line.modelData.text === "" ? "♪" : line.modelData.text
                                        wrapMode: Text.WordWrap
                                        horizontalAlignment: Player.lyricsSynced ? Text.AlignHCenter : Text.AlignLeft
                                        font.pixelSize: line.current ? 21 : 17
                                        font.weight: line.current ? Font.Bold : Font.Medium
                                        color: line.current ? Appearance.accentColor : Appearance.fgColor
                                        opacity: !Player.lyricsSynced || line.current ? 1 : 0.4

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Appearance.animNormal
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: Player.lyricsSynced
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Player.seek(line.modelData.t)
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 20
                                visible: Player.lyrics.length === 0
                                spacing: 8

                                Cover {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 220
                                    Layout.preferredHeight: 220
                                    radius: 20
                                    source: Player.track ? Player.track.cover : ""
                                    symbolSize: 64
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 10
                                    horizontalAlignment: Text.AlignHCenter
                                    text: Player.track ? Player.track.title : "Nothing is playing"
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: Player.track !== null
                                    text: Player.track ? [Player.track.artist, Player.track.album].filter(x => x).join(" · ") : ""
                                    elide: Text.ElideRight
                                    color: Appearance.mutedColor
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 8
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: Player.track !== null
                                    text: "No lyrics. Put a .lrc file with the same name next to the track."
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: 12
                                    color: Appearance.mutedColor
                                }
                            }
                        }

                        // the queue, dragged into order by the handle on the left
                        ColumnLayout {
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Player.queue.length === 0 ? "The queue is empty" : (Player.queue.length + " tracks, " + Math.max(0, Player.queue.length - Player.index - 1) + " to go")
                                    color: Appearance.mutedColor
                                    font.pixelSize: 13
                                }

                                IconButton {
                                    visible: Player.queue.length > 0
                                    icon: "delete_sweep"
                                    size: 32
                                    iconSize: 20
                                    onClicked: Player.clearQueue()
                                }
                            }

                            Flickable {
                                id: queueView

                                readonly property int rowHeight: 52
                                readonly property int step: rowHeight + 2
                                // slots[i] is the place the track now at i takes while one is dragged
                                property var slots: []
                                property int dragged: -1

                                function reset() {
                                    const s = [];
                                    for (let i = 0; i < Player.queue.length; i++)
                                        s.push(i);
                                    slots = s;
                                }

                                function moveTo(from, target) {
                                    const next = slots.slice();
                                    const old = next[from];
                                    for (let i = 0; i < next.length; i++) {
                                        if (i === from)
                                            continue;
                                        if (old < target && next[i] > old && next[i] <= target)
                                            next[i] -= 1;
                                        else if (old > target && next[i] < old && next[i] >= target)
                                            next[i] += 1;
                                    }
                                    next[from] = target;
                                    slots = next;
                                }

                                function finish() {
                                    const order = [];
                                    for (let i = 0; i < slots.length; i++)
                                        order[slots[i]] = i;
                                    dragged = -1;
                                    if (order.some((o, at) => o !== at))
                                        Player.reorder(order);
                                    else
                                        reset();
                                }

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentHeight: Player.queue.length * step
                                interactive: dragged < 0
                                boundsBehavior: Flickable.StopAtBounds
                                Component.onCompleted: reset()

                                Connections {
                                    function onQueueChanged() {
                                        queueView.reset();
                                    }

                                    target: Player
                                }

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }

                                Repeater {
                                    model: Player.queue.length

                                    delegate: Item {
                                        id: qrow

                                        required property int index
                                        readonly property string path: Player.queue[index] ?? ""
                                        readonly property var track: Library.byPath[path] ?? Library.track(path)
                                        readonly property bool current: index === Player.index
                                        readonly property bool dragging: queueView.dragged === index
                                        property real dragY: 0

                                        width: queueView.width - 8
                                        height: queueView.rowHeight
                                        y: dragging ? dragY : (queueView.slots[index] ?? index) * queueView.step
                                        z: dragging ? 2 : 0

                                        Behavior on y {
                                            enabled: !qrow.dragging
                                            NumberAnimation {
                                                duration: Appearance.animFast
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 14
                                            color: qrow.dragging ? Appearance.surfaceHighColor : (qrow.current ? Qt.alpha(Appearance.accentColor, 0.18) : (rowHover.hovered ? Appearance.surfaceHighColor : "transparent"))
                                        }

                                        HoverHandler {
                                            id: rowHover
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Player.jump(qrow.index)
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Item {
                                                Layout.preferredWidth: 28
                                                Layout.fillHeight: true

                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    icon: "drag_indicator"
                                                    font.pixelSize: 20
                                                    color: Appearance.mutedColor
                                                }

                                                MouseArea {
                                                    id: grip

                                                    property real grab: 0

                                                    anchors.fill: parent
                                                    cursorShape: Qt.SizeAllCursor
                                                    onPressed: mouse => {
                                                        const p = grip.mapToItem(queueView.contentItem, mouse.x, mouse.y);
                                                        grab = p.y - qrow.y;
                                                        qrow.dragY = qrow.y;
                                                        queueView.dragged = qrow.index;
                                                    }
                                                    onPositionChanged: mouse => {
                                                        if (!pressed)
                                                            return;
                                                        const p = grip.mapToItem(queueView.contentItem, mouse.x, mouse.y);
                                                        const max = (Player.queue.length - 1) * queueView.step;
                                                        qrow.dragY = Math.max(0, Math.min(max, p.y - grab));
                                                        const target = Math.round(qrow.dragY / queueView.step);
                                                        if (target !== queueView.slots[qrow.index])
                                                            queueView.moveTo(qrow.index, target);
                                                    }
                                                    onReleased: queueView.finish()
                                                    onCanceled: queueView.finish()
                                                }
                                            }

                                            Cover {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 8
                                                source: qrow.track.cover
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: qrow.track.title
                                                    elide: Text.ElideRight
                                                    font.pixelSize: 13
                                                    font.weight: qrow.current ? Font.Bold : Font.Medium
                                                    color: qrow.current ? Appearance.accentColor : Appearance.fgColor
                                                }

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: qrow.track.artist || "Unknown artist"
                                                    elide: Text.ElideRight
                                                    font.pixelSize: 11
                                                    color: Appearance.mutedColor
                                                }
                                            }

                                            IconButton {
                                                visible: rowHover.hovered && !qrow.dragging
                                                icon: "close"
                                                size: 28
                                                iconSize: 18
                                                onClicked: Player.removeAt(qrow.index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
            }

            // the controls
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 92
                radius: 24
                color: Appearance.surfaceColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 18
                    spacing: 16

                    RowLayout {
                        Layout.preferredWidth: 270
                        Layout.maximumWidth: 270
                        spacing: 12

                        Cover {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: 14
                            source: Player.track ? Player.track.cover : ""

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePane("lyrics")
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: Player.track ? Player.track.title : "Nothing is playing"
                                elide: Text.ElideRight
                                font.weight: Font.Bold
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Player.error !== "" ? "Cannot play this file" : (Player.track ? (Player.track.artist || "Unknown artist") : "Pick a track")
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                color: Player.error !== "" ? Qt.rgba(1, 0.45, 0.45, 1) : Appearance.mutedColor
                            }
                        }

                        IconButton {
                            visible: Player.hasTrack
                            readonly property bool fav: Player.hasTrack && Library.favorites[Player.currentPath] === true

                            icon: "favorite"
                            iconFill: fav ? 1 : 0
                            toggled: fav
                            size: 34
                            iconSize: 20
                            onClicked: Library.toggleFavorite(Player.currentPath)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6

                            IconButton {
                                icon: "shuffle"
                                toggled: Player.shuffle
                                size: 38
                                iconSize: 20
                                onClicked: Player.setShuffle(!Player.shuffle)
                            }

                            IconButton {
                                icon: "skip_previous"
                                iconFill: 1
                                size: 40
                                iconSize: 26
                                onClicked: Player.previous()
                            }

                            Rectangle {
                                implicitWidth: 52
                                implicitHeight: 52
                                radius: 26
                                color: playArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor
                                scale: playArea.pressed ? 0.94 : 1
                                opacity: Player.hasTrack ? 1 : 0.5

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Appearance.animFast
                                    }
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    icon: Player.playing ? "pause" : "play_arrow"
                                    fill: 1
                                    font.pixelSize: 32
                                    color: Appearance.accentContrastColor
                                }

                                MouseArea {
                                    id: playArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Player.toggle()
                                }
                            }

                            IconButton {
                                icon: "skip_next"
                                iconFill: 1
                                size: 40
                                iconSize: 26
                                onClicked: Player.next()
                            }

                            IconButton {
                                icon: Player.repeat === "one" ? "repeat_one" : "repeat"
                                toggled: Player.repeat !== "off"
                                size: 38
                                iconSize: 20
                                onClicked: Player.cycleRepeat()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            StyledText {
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignRight
                                text: Library.format((seek.dragging ? seek.dragValue * Player.durationMs : Player.positionMs) / 1000)
                                font.pixelSize: 12
                                color: Appearance.mutedColor
                            }

                            AudioSlider {
                                id: seek

                                Layout.fillWidth: true
                                value: Player.durationMs > 0 ? Player.positionMs / Player.durationMs : 0
                                onCommitted: v => Player.seek(v * Player.durationMs)
                            }

                            StyledText {
                                Layout.preferredWidth: 44
                                text: Library.format(Player.durationMs / 1000)
                                font.pixelSize: 12
                                color: Appearance.mutedColor
                            }
                        }
                    }

                    RowLayout {
                        Layout.preferredWidth: 300
                        Layout.maximumWidth: 300
                        spacing: 6

                        PillButton {
                            text: Player.speed + "×"
                            toggled: Player.speed !== 1
                            onClicked: {
                                const steps = [0.75, 1, 1.25, 1.5, 2];
                                const at = steps.indexOf(Player.speed);
                                Player.setSpeed(steps[(at + 1) % steps.length]);
                            }
                        }

                        Dropdown {
                            icon: "bedtime"
                            caption: Player.sleeping ? Player.sleepLabel : ""
                            placeholder: ""
                            popupWidth: 170
                            model: [
                                {
                                    "label": "Sleep timer off",
                                    "value": 0
                                },
                                {
                                    "label": "15 minutes",
                                    "value": 15
                                },
                                {
                                    "label": "30 minutes",
                                    "value": 30
                                },
                                {
                                    "label": "45 minutes",
                                    "value": 45
                                },
                                {
                                    "label": "1 hour",
                                    "value": 60
                                },
                                {
                                    "label": "End of this track",
                                    "value": -1
                                }
                            ]
                            onSelected: v => Player.setSleep(v)
                        }

                        IconButton {
                            icon: Player.muted || Player.volume === 0 ? "volume_off" : (Player.volume < 0.4 ? "volume_down" : "volume_up")
                            size: 34
                            iconSize: 20
                            onClicked: {
                                Player.muted = !Player.muted;
                                Player.save();
                            }
                        }

                        AudioSlider {
                            Layout.fillWidth: true
                            value: Player.muted ? 0 : Player.volume
                            onMoved: v => Player.setVolume(v)
                            onCommitted: v => Player.setVolume(v)
                        }
                    }

                    RowLayout {
                        spacing: 0

                        IconButton {
                            icon: "lyrics"
                            toggled: root.pane === "lyrics"
                            size: 38
                            iconSize: 22
                            onClicked: root.togglePane("lyrics")
                        }

                        IconButton {
                            icon: "queue_music"
                            toggled: root.pane === "queue"
                            size: 38
                            iconSize: 22
                            onClicked: root.togglePane("queue")
                        }
                    }
                }
            }
        }
    }

    // the audio folders
    Popup {
        id: foldersPopup

        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        width: 460
        padding: 18
        background: Rectangle {
            radius: 24
            color: Qt.alpha(Appearance.bgColor, 1)
            border.width: 1
            border.color: Appearance.hairlineColor
        }

        ColumnLayout {
            width: parent.width
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: "Audio folders"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                IconButton {
                    icon: "sync"
                    size: 34
                    iconSize: 20
                    onClicked: Library.refresh()
                }

                IconButton {
                    icon: "close"
                    size: 34
                    iconSize: 20
                    onClicked: foldersPopup.close()
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: "Tracks and videos in these folders and the folders inside them are in the library. A track is read once, and again only when its file changes."
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                color: Appearance.mutedColor
            }

            Repeater {
                model: Library.folders

                delegate: Rectangle {
                    id: folderRow

                    required property string modelData

                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 14
                    color: Appearance.surfaceColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 6
                        spacing: 10

                        MaterialSymbol {
                            icon: "folder"
                            font.pixelSize: 20
                            color: Appearance.mutedColor
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: folderRow.modelData.replace(Library.home, "~")
                            elide: Text.ElideMiddle
                        }

                        StyledText {
                            text: Library.tracks.filter(t => t.path.startsWith(folderRow.modelData + "/")).length
                            font.pixelSize: 12
                            color: Appearance.mutedColor
                        }

                        IconButton {
                            icon: "close"
                            size: 30
                            iconSize: 18
                            onClicked: Library.removeFolder(folderRow.modelData)
                        }
                    }
                }
            }

            PillButton {
                text: "Add a folder"
                icon: "add"
                onClicked: folderDialog.open()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: drop.containsDrag
        color: Qt.alpha(Appearance.bgColor, 0.85)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                icon: "library_add"
                font.pixelSize: 56
                color: Appearance.accentColor
            }

            StyledText {
                text: "Drop to play"
                font.pixelSize: 20
                font.weight: Font.Bold
            }
        }
    }
}
