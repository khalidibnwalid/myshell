import "../../components"
import "../../config"
import "components"
import "views"
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell

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
    // the window can be closed while the sound goes on
    property bool shown: false
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
    readonly property string listTitle: detailItem ? (detail.kind === "album" ? detailItem.title : detailItem.name) : sectionInfo.label
    readonly property string viewKind: detailItem ? "tracks" : (section === "albums" ? "albums" : (section === "artists" ? "artists" : "tracks"))
    readonly property var sectionInfo: sections.find(s => s.id === section)

    function openWindow() {
        if (shown) {
            raise();
            requestActivate();
        } else {
            shown = true;
        }
    }

    function go(id) {
        section = id;
        detail = null;
        query = "";
        topBar.clearSearch();
    }

    function playShown(i) {
        Player.playList(shownTracks.map(t => t.path), i);
    }

    function playAll() {
        Player.shuffle = false;
        playShown(0);
    }

    function shuffleAll() {
        Player.playShuffled(shownTracks.map(t => t.path));
    }

    function focusSearch() {
        sidebarOpen = true;
        topBar.focusSearch();
    }

    function openFiles() {
        openDialog.open();
    }

    // Escape: clear the search, then leave an open album or artist, then close the window
    function back() {
        if (query !== "") {
            topBar.clearSearch();
            query = "";
        } else if (detail) {
            detail = null;
        } else {
            shown = false;
        }
    }

    function togglePane(which) {
        pane = pane === which ? "" : which;
    }

    width: 1100
    height: 720
    minimumWidth: 900
    minimumHeight: 520
    title: "Audio"
    visible: root.shown
    color: Qt.alpha(Appearance.bgColor, Appearance.isLight ? 1 - Math.pow(1 - Config.appearance.settingsOpacity, 2) : Config.appearance.settingsOpacity)
    onClosing: root.shown = false
    onVisibleChanged: {
        if (visible)
            Library.refresh();
    }
    // the library and the saved queue are read from the start of the shell
    Component.onCompleted: {
        Library.load();
        Player.load();
    }

    // a quit or raise asked for over MPRIS
    Connections {
        function onRaiseRequested() {
            root.openWindow();
        }

        function onQuitRequested() {
            root.shown = false;
        }

        target: Player
    }

    // The program is only here while it is used: a minute after the window is closed and the sound is
    // off it quits, with the queue and the place saved.
    Timer {
        interval: 60000
        running: Player.loaded && !root.shown && !Player.playing
        onTriggered: {
            Player.save();
            Qt.quit();
        }
    }

    AudioIpc {
        window: root
    }

    AudioKeys {
        window: root
        typing: topBar.typing
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

                Sidebar {
                    open: root.sidebarOpen
                    sections: root.sections
                    section: root.section
                    onSelected: id => root.go(id)
                    onFoldRequested: root.sidebarOpen = false
                    onFoldersRequested: folders.open()
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    TopBar {
                        id: topBar

                        title: root.listTitle
                        sidebarOpen: root.sidebarOpen
                        canGoBack: root.detail !== null
                        showSort: root.viewKind === "tracks" && !root.detailItem && root.section !== "recent"
                        sortKey: root.sortKey
                        onSidebarRequested: root.sidebarOpen = true
                        onBackClicked: root.detail = null
                        onQueryEdited: text => root.query = text
                        onSortSelected: key => root.sortKey = key
                        onOpenRequested: root.openFiles()
                        onCloseRequested: root.shown = false
                    }

                    DetailHeader {
                        visible: root.detailItem !== null
                        kind: root.detail ? root.detail.kind : "album"
                        item: root.detailItem
                        onPlayRequested: root.playAll()
                        onShuffleRequested: root.shuffleAll()
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.viewKind === "tracks" ? 0 : (root.viewKind === "albums" ? 1 : 2)

                        TracksView {
                            tracks: root.shownTracks
                            showActions: !root.detailItem
                            canClear: root.section === "recent"
                            numbered: root.detail !== null && root.detail.kind === "album"
                            showAlbum: !(root.detail !== null && root.detail.kind === "album")
                            emptyIcon: root.query !== "" ? "search_off" : root.sectionInfo.icon
                            emptyText: root.query !== "" ? "Nothing found" : (root.section === "favorites" ? "No favourites yet" : (root.section === "recent" ? "Nothing played yet" : (Library.scanning ? "Indexing your audio…" : "No audio found")))
                            emptyHint: root.query !== "" ? "" : (root.section === "favorites" ? "Press the heart on a track" : (root.section === "tracks" && !Library.scanning ? "Add a folder, or drop files here" : ""))
                            onPlayRequested: root.playAll()
                            onShuffleRequested: root.shuffleAll()
                            onClearRequested: Library.clearHistory()
                            onActivated: i => root.playShown(i)
                        }

                        AlbumGrid {
                            albums: root.shownAlbums
                            onOpened: key => root.detail = {
                                "kind": "album",
                                "key": key
                            }
                        }

                        ArtistList {
                            artists: root.shownArtists
                            onOpened: key => root.detail = {
                                "kind": "artist",
                                "key": key
                            }
                        }
                    }
                }

                SidePane {
                    pane: root.pane
                    onPaneSelected: p => root.pane = p
                }
            }

            PlayerBar {
                Layout.fillWidth: true
                pane: root.pane
                onPaneToggled: p => root.togglePane(p)
            }
        }
    }

    FoldersPopup {
        id: folders

        onAddRequested: folderDialog.open()
    }

    DropHint {
        anchors.fill: parent
        visible: drop.containsDrag
    }
}
