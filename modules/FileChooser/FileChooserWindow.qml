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
    readonly property Item activeView: grid ? gridView : list

    property string folder: home
    property var selected: []
    property bool showHidden: false
    property int filterIndex: 0
    property string saveName: ""
    property var placeNames: []

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

    function go(path) {
        let p = path.trim();
        if (p === "~" || p.startsWith("~/"))
            p = home + p.slice(1);
        if (!p.startsWith("/"))
            p = join(folder, p);
        p = p.replace(/\/+$/, "");
        folder = p === "" ? "/" : p;
        selected = [];
        list.currentIndex = -1;
        gridView.currentIndex = -1;
    }

    function setName(name) {
        // FieldInput shows `value` unless the user is typing; a new name replaces what was typed
        nameField.dirty = false;
        saveName = name;
    }

    function isImage(name) {
        const ext = name.indexOf(".") >= 0 ? name.split(".").pop().toLowerCase() : "";
        return ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "ico"].indexOf(ext) >= 0;
    }

    // a row or tile became the current one by keyboard
    function picked(view) {
        if (view.currentIndex >= 0 && view.activeFocus)
            clickEntry(folderModel.get(view.currentIndex, "filePath"), folderModel.isFolder(view.currentIndex), 0);
    }

    function enter(view) {
        if (view.currentIndex >= 0)
            activate(folderModel.get(view.currentIndex, "filePath"), folderModel.isFolder(view.currentIndex));
        else
            accept();
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
            activeView.forceActiveFocus();
    }

    onRequestChanged: if (request)
        init()
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

    FolderListModel {
        id: folderModel

        folder: window.toUrl(window.folder)
        showDirs: true
        showFiles: !window.pickDir
        showDirsFirst: true
        showHidden: window.showHidden
        showDotAndDotDot: false
        caseSensitive: false
        nameFilters: {
            const p = window.activeFilter?.patterns ?? [];
            return p.length > 0 ? p : ["*"];
        }
    }

    GlassDialog {
        id: dialog

        anchors.centerIn: parent
        dialogWidth: 780
        compact: true
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
        onButtonClicked: key => key === "ok" ? window.accept() : window.cancelled()
        // Ctrl+G switches between rows and tiles, Ctrl+H shows hidden files
        Keys.onPressed: event => {
            if (!(event.modifiers & Qt.ControlModifier))
                return;
            if (event.key === Qt.Key_G) {
                Config.fileChooser.grid = !Config.fileChooser.grid;
                event.accepted = true;
            } else if (event.key === Qt.Key_H) {
                window.showHidden = !window.showHidden;
                event.accepted = true;
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                icon: "arrow_upward"
                enabled: window.folder !== "/"
                onClicked: window.go(window.parentOf(window.folder))
            }

            FieldInput {
                Layout.fillWidth: true
                icon: "folder"
                value: window.folder
                onCommitted: text => window.go(text)
            }

            IconButton {
                icon: window.grid ? "view_list" : "grid_view"
                onClicked: Config.fileChooser.grid = !Config.fileChooser.grid
            }

            IconButton {
                icon: window.showHidden ? "visibility" : "visibility_off"
                toggled: window.showHidden
                onClicked: window.showHidden = !window.showHidden
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // places
            ColumnLayout {
                // a nested layout fills by default, which would squeeze the file list out
                Layout.fillWidth: false
                Layout.preferredWidth: 170
                Layout.maximumWidth: 170
                Layout.alignment: Qt.AlignTop
                spacing: 2

                Repeater {
                    model: {
                        const list = [
                            {
                                "name": "Home",
                                "path": window.home,
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
                        for (const n of window.placeNames)
                            list.push({
                                "name": n,
                                "path": window.home + "/" + n,
                                "icon": icons[n]
                            });
                        list.push({
                            "name": "Computer",
                            "path": "/",
                            "icon": "computer"
                        });
                        return list;
                    }

                    Rectangle {
                        id: place

                        required property var modelData
                        readonly property bool current: window.folder === modelData.path

                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 19
                        color: current ? Qt.alpha(Appearance.accentColor, 0.22) : (placeArea.containsMouse ? Appearance.surfaceColor : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialSymbol {
                                icon: place.modelData.icon
                                font.pixelSize: 18
                                color: place.current ? Appearance.accentColor : Appearance.mutedColor
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: place.modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                font.weight: place.current ? Font.DemiBold : Font.Normal
                            }
                        }

                        MouseArea {
                            id: placeArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.go(place.modelData.path)
                        }
                    }
                }
            }

            // files
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 340
                radius: 20
                color: Appearance.surfaceColor
                clip: true

                ListView {
                    id: list

                    anchors.fill: parent
                    anchors.margins: 6
                    visible: !window.grid
                    model: folderModel
                    currentIndex: -1
                    clip: true
                    activeFocusOnTab: true
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: true
                    onCurrentIndexChanged: window.picked(list)
                    Keys.onReturnPressed: window.enter(list)
                    Keys.onEnterPressed: Keys.returnPressed(event)
                    Keys.onBackPressed: window.go(window.parentOf(window.folder))

                    delegate: Rectangle {
                        id: row

                        required property int index
                        required property string fileName
                        required property string filePath
                        required property bool fileIsDir
                        required property real fileSize
                        readonly property bool picked: window.selected.indexOf(filePath) >= 0

                        width: ListView.view.width
                        height: 46
                        radius: 14
                        color: picked ? Qt.alpha(Appearance.accentColor, 0.22) : (rowArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            FileThumb {
                                size: 32
                                path: row.filePath
                                dir: row.fileIsDir
                                icon: window.iconFor(row.fileName)
                                image: window.isImage(row.fileName)
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.fileName
                                elide: Text.ElideMiddle
                                font.pixelSize: 13
                            }

                            StyledText {
                                visible: !row.fileIsDir
                                text: window.sizeText(row.fileSize)
                                color: Appearance.mutedColor
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: mouse => {
                                list.forceActiveFocus();
                                list.currentIndex = row.index;
                                window.clickEntry(row.filePath, row.fileIsDir, mouse.modifiers);
                            }
                            onDoubleClicked: window.activate(row.filePath, row.fileIsDir)
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: folderModel.count === 0
                        text: "This folder is empty"
                        color: Appearance.mutedColor
                        font.pixelSize: 13
                    }
                }

                // the same files as tiles with bigger pictures
                GridView {
                    id: gridView

                    anchors.fill: parent
                    anchors.margins: 6
                    visible: window.grid
                    model: folderModel
                    currentIndex: -1
                    clip: true
                    activeFocusOnTab: true
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: true
                    // whole columns that fill the width
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 128)))
                    cellHeight: 134
                    onCurrentIndexChanged: window.picked(gridView)
                    Keys.onReturnPressed: window.enter(gridView)
                    Keys.onEnterPressed: Keys.returnPressed(event)
                    Keys.onBackPressed: window.go(window.parentOf(window.folder))

                    delegate: Item {
                        id: tile

                        required property int index
                        required property string fileName
                        required property string filePath
                        required property bool fileIsDir
                        readonly property bool picked: window.selected.indexOf(filePath) >= 0

                        width: gridView.cellWidth
                        height: gridView.cellHeight

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
                                path: tile.filePath
                                dir: tile.fileIsDir
                                icon: window.iconFor(tile.fileName)
                                image: window.isImage(tile.fileName)
                            }

                            StyledText {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.fileName
                                elide: Text.ElideMiddle
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: tileArea

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: mouse => {
                                    gridView.forceActiveFocus();
                                    gridView.currentIndex = tile.index;
                                    window.clickEntry(tile.filePath, tile.fileIsDir, mouse.modifiers);
                                }
                                onDoubleClicked: window.activate(tile.filePath, tile.fileIsDir)
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: folderModel.count === 0
                        text: "This folder is empty"
                        color: Appearance.mutedColor
                        font.pixelSize: 13
                    }
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
            onEdited: text => window.saveName = text
            onAccepted: window.accept()
        }

        // the filters sit on the left of the button row
        footer: [
            Segmented {
                visible: window.filters.length > 1
                model: window.filters.map((f, n) => ({
                            "label": f.name,
                            "value": n
                        }))
                value: window.filterIndex
                onSelected: n => window.filterIndex = n
            }
        ]
    }
}
