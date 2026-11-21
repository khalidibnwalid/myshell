import "../../components/"
import "../../config/"
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// One file dialog asked for through xdg-desktop-portal (see FileChooser.qml): open files or a folder, or save
// a file, in a GlassDialog. `request` is { id, kind: "open" | "save" | "savefiles", app, title, options }.
//
// Keyboard (everything works without a mouse): typing anywhere searches the folder, Down goes from the search box
// to the list, Up on the first row goes back, arrows/Home/End/PageUp/PageDown move, Enter opens or accepts,
// Backspace or Alt+Up goes to the parent folder, Ctrl+L edits the path, Ctrl+F searches, Ctrl+G switches
// rows/tiles, Ctrl+H shows hidden files, Ctrl+A selects all (several files), Escape clears the search and then
// cancels. Tab visits the toolbar, the places, the files, the name, the filters and the buttons.
PanelWindow {
    id: window

    property var request
    // where the last dialog ended, used when the app names no folder
    property string startFolder: ""

    signal chosen(var paths)
    signal cancelled()

    readonly property var opts: request?.options ?? ({})
    readonly property string kind: request?.kind ?? "open"
    readonly property bool saving: kind === "save"
    readonly property bool pickDir: opts.directory === true
    readonly property bool multiple: opts.multiple === true && !saving
    readonly property string home: Quickshell.env("HOME")
    readonly property var filters: opts.filters ?? []
    readonly property var activeFilter: filterIndex >= 0 && filterIndex < filters.length ? filters[filterIndex] : null
    readonly property var screenNow: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    readonly property bool grid: Config.fileChooser.grid

    property string folder: home
    property var selected: []
    property bool showHidden: false
    property int filterIndex: 0
    property string saveName: ""
    property var placeNames: []
    property var thumbExts: ["png", "jpg", "jpeg", "gif", "svg", "bmp", "ico"]
    // what the search box holds, and the entries of the folder that match it
    property string query: ""
    property var entries: []

    readonly property var places: {
        const out = [
            {
                "name": "Home",
                "path": home,
                "icon": "home"
            }
        ];
        const icons = {
            "Desktop": "desktop_windows",
            "Documents": "description",
            "Downloads": "download",
            "Music": "music_note",
            "Pictures": "image",
            "Videos": "movie"
        };
        for (const n of placeNames)
            out.push({
                "name": n,
                "path": home + "/" + n,
                "icon": icons[n]
            });
        out.push({
            "name": "Computer",
            "path": "/",
            "icon": "computer"
        });
        return out;
    }

    readonly property bool validName: saveName.trim() !== "" && saveName.indexOf("/") < 0
    readonly property bool canAccept: saving ? validName : (pickDir ? true : selected.length > 0)
    readonly property string acceptText: {
        if (opts.acceptLabel)
            return String(opts.acceptLabel).replace(/_/g, "");
        return saving ? "Save" : (pickDir ? "Select" : "Open");
    }
    readonly property string dialogTitle: {
        if (request?.title)
            return request.title;
        if (saving)
            return "Save file";
        return pickDir ? (multiple ? "Choose folders" : "Choose a folder") : (multiple ? "Open files" : "Open file");
    }

    function join(dir, name) {
        return (dir === "/" ? "" : dir) + "/" + name;
    }

    function toUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function parentOf(path) {
        const p = path.replace(/\/[^\/]+\/?$/, "");
        return p === "" ? "/" : p;
    }

    // the folder's entries whose names contain every word of the search
    function rebuild() {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
        const out = [];
        for (let i = 0; i < folderModel.count; i++) {
            const name = folderModel.get(i, "fileName");
            const low = name.toLowerCase();
            if (words.every(w => low.indexOf(w) >= 0))
                out.push({
                    "name": name,
                    "path": folderModel.get(i, "filePath"),
                    "dir": folderModel.isFolder(i),
                    "size": folderModel.get(i, "fileSize"),
                    "modified": folderModel.get(i, "fileModified")
                });
        }
        entries = out;
    }

    // a column title was clicked: that column, or the other way round when it is already the sort
    function sortBy(key) {
        if (Config.fileChooser.sortBy === key)
            Config.fileChooser.sortReversed = !Config.fileChooser.sortReversed;
        else {
            Config.fileChooser.sortBy = key;
            Config.fileChooser.sortReversed = false;
        }
    }

    function clearSearch() {
        search.dirty = false;
        query = "";
    }

    function go(path) {
        let p = path.trim();
        if (p === "~" || p.startsWith("~/"))
            p = home + p.slice(1);
        if (!p.startsWith("/"))
            p = join(folder, p);
        p = p.replace(/\/+$/, "");
        folder = p === "" ? "/" : p;
        selected = [];
        clearSearch();
        files.resetCurrent();
    }

    function setName(name) {
        // FieldInput shows `value` unless the user is typing; a new name replaces what was typed
        nameField.dirty = false;
        saveName = name;
    }

    function clickEntry(path, isDir, mods) {
        if (isDir && !pickDir) {
            selected = [];
            return;
        }
        if (multiple && (mods & Qt.ControlModifier)) {
            const i = selected.indexOf(path);
            selected = i >= 0 ? selected.filter(p => p !== path) : selected.concat([path]);
        } else {
            selected = [path];
        }
        if (saving && !isDir)
            setName(path.split("/").pop());
    }

    function activate(path, isDir) {
        if (isDir)
            go(path);
        else if (canAccept)
            accept();
    }

    // Enter in the search box: open the first match
    function openFirst() {
        const e = entries[0];
        if (!e)
            return;
        clickEntry(e.path, e.dir, 0);
        activate(e.path, e.dir);
    }

    function focusList(index) {
        files.focusIndex(index);
    }

    function selectAll() {
        if (!multiple)
            return;
        selected = entries.filter(e => pickDir ? e.dir : !e.dir).map(e => e.path);
    }

    // Escape clears a search first; only then it cancels the dialog
    function escapeKey(event) {
        if (query !== "") {
            clearSearch();
            files.focusView();
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }

    function accept() {
        if (!canAccept)
            return;
        let paths;
        if (saving)
            paths = [join(folder, saveName.trim())];
        else if (pickDir)
            paths = selected.length > 0 ? selected : [folder];
        else
            paths = selected;
        chosen(paths);
    }

    function init() {
        const dir = opts.currentFolder && opts.currentFolder !== "" ? opts.currentFolder : (startFolder !== "" ? startFolder : home);
        showHidden = false;
        filterIndex = 0;
        if (opts.currentFilter) {
            const i = filters.findIndex(f => f.name === opts.currentFilter.name);
            if (i >= 0)
                filterIndex = i;
        }
        go(dir);
        setName(opts.currentName ?? "");
        if (saving)
            nameField.focusInput();
        else
            files.focusView();
    }

    onRequestChanged: if (request)
        init()
    onQueryChanged: rebuild()
    Component.onCompleted: if (request)
        init()

    screen: screenNow
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "quickshell-filechooser"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // transparent, but it keeps clicks off the windows below
    MouseArea {
        anchors.fill: parent
    }

    Process {
        running: true
        command: ["sh", "-c", 'for d in Desktop Documents Downloads Music Pictures Videos; do [ -d "$HOME/$d" ] && echo "$d"; done']
        stdout: StdioCollector {
            onStreamFinished: window.placeNames = this.text.trim().split("\n").filter(n => n !== "")
        }
    }

    // webp and tiff need the qt6-imageformats plugins; without them those files show their type symbol
    Process {
        id: formatsProc

        running: true
        command: ["sh", "-c", "ls /usr/lib/qt6/plugins/imageformats /usr/lib64/qt6/plugins/imageformats 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = this.text;
                const more = [];
                if (found.indexOf("libqwebp") >= 0)
                    more.push("webp");
                if (found.indexOf("libqtiff") >= 0)
                    more.push("tif", "tiff");
                window.thumbExts = window.thumbExts.concat(more);
            }
        }
    }

    FolderListModel {
        id: folderModel

        folder: window.toUrl(window.folder)
        showDirs: true
        showFiles: !window.pickDir
        showDirsFirst: true
        showHidden: window.showHidden
        showDotAndDotDot: false
        caseSensitive: false
        sortField: ({
                "size": FolderListModel.Size,
                "time": FolderListModel.Time,
                "type": FolderListModel.Type
            })[Config.fileChooser.sortBy] ?? FolderListModel.Name
        sortReversed: Config.fileChooser.sortReversed
        nameFilters: {
            const p = window.activeFilter?.patterns ?? [];
            return p.length > 0 ? p : ["*"];
        }
    }

    // the model loads in the background: rebuild when it has (new) content
    Connections {
        target: folderModel

        function onCountChanged() {
            window.rebuild();
        }

        function onStatusChanged() {
            if (folderModel.status === FolderListModel.Ready)
                window.rebuild();
        }
    }

    TypeToSearch {
        id: ahead

        onTyped: text => search.append(text)
    }

    GlassDialog {
        id: dialog

        anchors.centerIn: parent
        dialogWidth: 780
        compact: true
        movable: true
        minAlpha: 0.85
        icon: window.saving ? "save" : (window.pickDir ? "folder_open" : "file_open")
        title: window.dialogTitle
        message: window.request?.app ? "For " + window.request.app : ""
        buttons: [
            {
                "text": "Cancel",
                "key": "cancel"
            },
            {
                "text": window.acceptText,
                "key": "ok",
                "primary": true,
                "enabled": window.canAccept
            }
        ]
        Accessible.role: Accessible.Dialog
        Accessible.name: window.dialogTitle
        onButtonClicked: key => key === "ok" ? window.accept() : window.cancelled()

        // keys that no control took: shortcuts, then typing (which goes to the search box)
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            const alt = event.modifiers & Qt.AltModifier;
            if (ctrl && event.key === Qt.Key_G)
                Config.fileChooser.grid = !Config.fileChooser.grid;
            else if (ctrl && event.key === Qt.Key_H)
                window.showHidden = !window.showHidden;
            else if (ctrl && event.key === Qt.Key_L) {
                pathField.focusInput();
                pathField.selectAll();
            } else if (ctrl && event.key === Qt.Key_F)
                search.focusInput();
            else if (ctrl && event.key === Qt.Key_A && window.multiple)
                window.selectAll();
            else if ((alt && event.key === Qt.Key_Up) || event.key === Qt.Key_Backspace)
                window.go(window.parentOf(window.folder));
            else
                ahead.press(event);
            // ahead.press accepts what it takes; the shortcuts above are always ours
            if (ctrl || alt || event.key === Qt.Key_Backspace)
                event.accepted = true;
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                icon: "arrow_upward"
                enabled: window.folder !== "/"
                Accessible.name: "Parent folder"
                onClicked: window.go(window.parentOf(window.folder))
            }

            FieldInput {
                id: pathField

                Layout.fillWidth: true
                icon: "folder"
                placeholder: "Folder"
                value: window.folder
                Accessible.name: "Folder path"
                onCommitted: text => window.go(text)
            }

            FieldInput {
                id: search

                Layout.preferredWidth: 200
                icon: "search"
                placeholder: "Type to search"
                value: window.query
                Accessible.name: "Search this folder"
                onEdited: text => window.query = text
                onAccepted: window.openFirst()
                Keys.onDownPressed: window.focusList(0)
                Keys.onEscapePressed: event => window.escapeKey(event)
            }

            // in the list the column titles sort; tiles have none, so they get these two
            Dropdown {
                visible: window.grid
                icon: "sort"
                popupWidth: 160
                implicitWidth: 120
                model: [
                    {
                        "label": "Name",
                        "value": "name"
                    },
                    {
                        "label": "Size",
                        "value": "size"
                    },
                    {
                        "label": "Modified",
                        "value": "time"
                    },
                    {
                        "label": "Type",
                        "value": "type"
                    }
                ]
                value: Config.fileChooser.sortBy
                Accessible.name: "Sort by"
                onSelected: v => Config.fileChooser.sortBy = v
            }

            IconButton {
                visible: window.grid
                icon: Config.fileChooser.sortReversed ? "arrow_downward" : "arrow_upward"
                Accessible.name: Config.fileChooser.sortReversed ? "Sorted in reverse" : "Sorted forwards"
                onClicked: Config.fileChooser.sortReversed = !Config.fileChooser.sortReversed
            }

            IconButton {
                icon: window.grid ? "view_list" : "grid_view"
                Accessible.name: window.grid ? "Show as list (Ctrl+G)" : "Show as tiles (Ctrl+G)"
                onClicked: Config.fileChooser.grid = !Config.fileChooser.grid
            }

            IconButton {
                icon: window.showHidden ? "visibility" : "visibility_off"
                toggled: window.showHidden
                Accessible.name: "Show hidden files (Ctrl+H)"
                onClicked: window.showHidden = !window.showHidden
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FilePlaces {
                places: window.places
                folder: window.folder
                onChose: path => window.go(path)
            }

            FileEntries {
                id: files

                entries: window.entries
                selected: window.selected
                grid: window.grid
                thumbExts: window.thumbExts
                emptyText: window.query !== "" ? "Nothing matches \"" + window.query.trim() + "\"" : "This folder is empty"
                onEntryClicked: (path, isDir, mods) => window.clickEntry(path, isDir, mods)
                onEntryActivated: (path, isDir) => window.activate(path, isDir)
                onAcceptRequested: window.accept()
                onTopReached: search.focusInput()
                searching: window.query !== ""
                sortBy: Config.fileChooser.sortBy
                sortReversed: Config.fileChooser.sortReversed
                onSortRequested: key => window.sortBy(key)
                onClearSearchRequested: {
                    window.clearSearch();
                    files.focusView();
                }
            }
        }

        FieldInput {
            id: nameField

            Layout.fillWidth: true
            visible: window.saving
            icon: "edit"
            placeholder: "File name"
            value: window.saveName
            Accessible.name: "File name"
            onEdited: text => window.saveName = text
            onAccepted: window.accept()
        }

        // the filters sit on the left of the button row
        footer: [
            // two or fewer fit as buttons; more would overflow the dialog, so they drop down
            Segmented {
                visible: window.filters.length > 1 && window.filters.length <= 2
                model: window.filters.map((f, n) => ({
                            "label": f.name,
                            "value": n
                        }))
                value: window.filterIndex
                onSelected: n => window.filterIndex = n
            },
            Dropdown {
                visible: window.filters.length > 2
                icon: "filter_list"
                popupAbove: true
                popupWidth: 300
                implicitWidth: 240
                model: window.filters.map((f, n) => ({
                            "label": f.name,
                            "value": n
                        }))
                value: window.filterIndex
                onSelected: n => window.filterIndex = n
            }
        ]
    }

    // pressing on the dialog's background gives the keyboard back to it, so typing searches again
    ClickAway {
        target: dialog
    }
}
