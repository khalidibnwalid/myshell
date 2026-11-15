import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell

SettingsPage {
    id: page

    readonly property var custom: Config.search?.bangs ?? ({})
    readonly property var customKeys: Object.keys(custom)
    readonly property var engines: Object.keys(Search.bangs).map(key => ({
        "label": Search.bangs[key].name,
        "value": key,
        "description": "!" + key
    }))
    readonly property int launches: Object.values(Search.usageData || {}).reduce((sum, n) => sum + n, 0)
    property string addError: ""
    // "" = the launcher's own page; "files" = how files are looked up
    property string inner: ""
    property string pickFor: ""
    readonly property var fileOpts: Search.fileOptions

    function shortPath(p) {
        return p === "~" ? "Home folder" : p.replace(/^\/home\/[^/]+/, "~");
    }

    function addTo(list, text) {
        const t = text.trim().replace(/\/+$/, "");
        if (t === "" || fileOpts[list].indexOf(t) >= 0)
            return;
        const change = {};
        change[list] = fileOpts[list].concat([t]);
        Search.setFileOptions(change);
    }

    function removeFrom(list, text) {
        const change = {};
        change[list] = fileOpts[list].filter(x => x !== text);
        Search.setFileOptions(change);
    }
    property string sourceError: ""
    readonly property var customSources: Config.search?.commandSources ?? []

    function setSource(name, on) {
        const next = Object.assign({}, Config.search?.sources ?? ({}));
        next[name] = on;
        Config.setIn("search", "sources", next);
    }

    function addSource() {
        const name = sourceName.text.trim();
        const command = sourceCommand.text.trim();
        if (name === "" || command === "") {
            sourceError = "Fill in both fields.";
            return;
        }
        if (customSources.some(c => c.name === name)) {
            sourceError = "A source with that name exists.";
            return;
        }
        sourceError = "";
        Config.setIn("search", "commandSources", customSources.concat([
            {
                "name": name,
                "command": command,
                "open": "xdg-open"
            }
        ]));
        sourceName.clear();
        sourceCommand.clear();
    }

    function removeSource(name) {
        Config.setIn("search", "commandSources", customSources.filter(c => c.name !== name));
        SearchProviders.setEnabled("cmd:custom:" + name, false);
    }

    function setBangs(next) {
        Config.setIn("search", "bangs", next);
    }

    function removeBang(key) {
        const next = Object.assign({}, custom);
        delete next[key];
        setBangs(next);
    }

    function addBang() {
        const key = newKey.text.trim().replace(/^!+/, "").toLowerCase();
        const name = newName.text.trim();
        const url = newUrl.text.trim();
        if (key === "" || name === "" || url === "") {
            addError = "Fill in all three fields.";
            return;
        }
        if (/\s/.test(key)) {
            addError = "The shortcut cannot contain spaces.";
            return;
        }
        if (!url.includes("%s")) {
            addError = "The address needs %s where the search words go.";
            return;
        }
        addError = "";
        const next = Object.assign({}, custom);
        next[key] = {
            "name": name,
            "url": url
        };
        setBangs(next);
        newKey.clear();
        newName.clear();
        newUrl.clear();
    }

    title: inner === "files" ? "Files and folders" : "Launcher"
    subtitle: inner === "files" ? "Where the launcher looks for files, and what it leaves out" : "Apps, files and web search from one box"

    headerActions: [
        PillButton {
            visible: page.inner !== ""
            icon: "arrow_back"
            text: "Launcher"
            onClicked: page.inner = ""
        }
    ]

    FolderDialog {
        id: folderDialog

        title: page.pickFor === "roots" ? "Choose a folder to look in" : "Choose a folder to leave out"
        onAccepted: {
            const path = decodeURIComponent(selectedFolder.toString().replace("file://", ""));
            const home = Quickshell.env("HOME");
            page.addTo(page.pickFor, path === home ? "~" : (path.startsWith(home + "/") ? "~" + path.slice(home.length) : path));
        }
    }

    // --- what the launcher searches ---
    SettingGroup {
        visible: page.inner === ""
        title: "Results from"

        Repeater {
            model: [
                {
                    "key": "apps",
                    "icon": "apps",
                    "title": "Apps",
                    "description": "Installed applications"
                },
                {
                    "key": "settings",
                    "icon": "settings",
                    "title": "Settings",
                    "description": "The Settings app and its pages, so \"wifi\" or \"keyboard\" opens that page"
                },
                {
                    "key": "hyprland",
                    "icon": "window",
                    "title": "Hyprland options",
                    "description": "Single window manager options, such as gaps or blur (needs Settings on)"
                },
                {
                    "key": "files",
                    "icon": "folder",
                    "title": "Files and folders",
                    "description": "Looked up in your home folder"
                },
                {
                    "key": "web",
                    "icon": "travel_explore",
                    "title": "Web search",
                    "description": "The last row that searches the web or opens an address"
                }
            ]

            delegate: SettingRow {
                id: sourceRow

                required property var modelData

                icon: modelData.icon
                title: modelData.title
                description: modelData.description

                // the lookup of files has options of its own
                IconButton {
                    visible: sourceRow.modelData.key === "files"
                    size: 32
                    iconSize: 22
                    icon: "chevron_right"
                    onClicked: page.inner = "files"
                }

                ToggleSwitch {
                    checked: Config.search?.sources?.[sourceRow.modelData.key] ?? true
                    onToggled: on => page.setSource(sourceRow.modelData.key, on)
                }
            }
        }
    }

    // --- which results come first ---
    SettingGroup {
        visible: page.inner === ""
        title: "Order of results"

        SettingRow {
            icon: "swap_vert"
            title: "Drag to sort"
            description: "Results from the top of this list come first. Apps are always the tiles at the very top."
        }

        SortableList {
            Layout.fillWidth: true
            items: Search.orderItems
            onReordered: ids => Search.setOrder(ids)
        }
    }

    // --- apps that hand their own results to the launcher ---
    SettingGroup {
        visible: page.inner === ""
        title: "Apps that offer results"

        SettingRow {
            icon: "info"
            title: "On for every app that offers them"
            description: "Apps like Files, Calculator and Firefox answer the launcher through a standard D-Bus search interface, the same one GNOME uses. Asking an app that is not running may start it in the background; switch off the ones you don't want."
        }

        Repeater {
            model: SearchProviders.builtinSources

            delegate: SettingRow {
                id: builtinRow

                required property var modelData

                icon: modelData.icon
                title: modelData.name
                description: modelData.description

                ToggleSwitch {
                    checked: SearchProviders.isEnabled(builtinRow.modelData.id)
                    onToggled: on => SearchProviders.setEnabled(builtinRow.modelData.id, on)
                }
            }
        }

        Repeater {
            model: SearchProviders.providers

            delegate: SettingRow {
                id: providerRow

                required property var modelData

                image: modelData.icon !== "" ? (modelData.icon.startsWith("/") ? "file://" + modelData.icon : Quickshell.iconPath(modelData.icon, true)) : ""
                icon: image === "" ? "apps" : ""
                title: modelData.name
                description: "Search provider  ·  " + modelData.busName

                ToggleSwitch {
                    checked: SearchProviders.isEnabled(providerRow.modelData.id)
                    onToggled: on => SearchProviders.setEnabled(providerRow.modelData.id, on)
                }
            }
        }
    }

    // --- sources of your own ---
    SettingGroup {
        visible: page.inner === ""
        title: "Your own sources"

        SettingRow {
            icon: "terminal"
            title: "Any command can be a source"
            description: "It gets the typed words as $1 and prints one result per line: title, a tab, a detail, a tab, and what to open (a file, folder or address). For example the recent tabs of a browser, if something exports them."
        }

        Repeater {
            model: page.customSources

            delegate: SettingRow {
                id: customRow

                required property var modelData

                icon: "terminal"
                title: modelData.name
                description: modelData.command

                IconButton {
                    size: 32
                    iconSize: 18
                    icon: "delete"
                    onClicked: page.removeSource(customRow.modelData.name)
                }

                ToggleSwitch {
                    checked: SearchProviders.isEnabled("cmd:custom:" + customRow.modelData.name)
                    onToggled: on => SearchProviders.setEnabled("cmd:custom:" + customRow.modelData.name, on)
                }
            }
        }

        SettingRow {
            icon: "add"
            title: "Add a source"
            description: page.sourceError !== "" ? page.sourceError : "A name and the command to run"

            FieldInput {
                id: sourceName

                implicitWidth: 130
                placeholder: "Name"
            }

            FieldInput {
                id: sourceCommand

                implicitWidth: 220
                placeholder: "my-script \"$1\""
                onAccepted: page.addSource()
            }

            PillButton {
                text: "Add"
                onClicked: page.addSource()
            }
        }
    }

    SettingGroup {
        visible: page.inner === ""
        title: "Web search"

        SettingRow {
            icon: "travel_explore"
            title: "Default search engine"
            description: "Used when a query has no !bang"

            Dropdown {
                model: page.engines
                value: Config.search?.defaultBang || "g"
                searchable: true
                popupWidth: 280
                onSelected: key => Config.setIn("search", "defaultBang", key)
            }
        }

        SettingRow {
            icon: "public"
            title: "Browser command"
            description: "Program that opens searches and links; empty uses xdg-open"

            FieldInput {
                value: Config.search?.browser ?? ""
                placeholder: "xdg-open"
                onCommitted: text => Config.setIn("search", "browser", text.trim())
            }
        }

        SettingRow {
            title: "Browser window class"
            description: "The browser is brought to the front after a search; empty skips this"

            FieldInput {
                value: Config.search?.browserClass ?? ""
                placeholder: "e.g. firefox"
                onCommitted: text => Config.setIn("search", "browserClass", text.trim())
            }
        }

        SettingRow {
            icon: "visibility_off"
            title: "Private window flag"
            description: "Passed to the browser for !!bang searches"

            FieldInput {
                value: Config.search?.privateFlag ?? ""
                placeholder: "--incognito"
                onCommitted: text => Config.setIn("search", "privateFlag", text.trim())
            }
        }
    }

    SettingGroup {
        visible: page.inner === ""
        title: "Your bangs"

        Repeater {
            model: page.customKeys

            delegate: SettingRow {
                id: bang

                required property string modelData

                title: "!" + modelData + "  ·  " + (page.custom[modelData]?.name ?? "")
                description: page.custom[modelData]?.url ?? ""

                IconButton {
                    icon: "delete"
                    onClicked: page.removeBang(bang.modelData)
                }
            }
        }

        SettingCard {
            StyledText {
                Layout.fillWidth: true
                text: "Add a bang"
                font.weight: Font.Medium
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                FieldInput {
                    id: newKey

                    implicitWidth: 110
                    placeholder: "Shortcut, e.g. mdn"
                    onAccepted: page.addBang()
                }

                FieldInput {
                    id: newName

                    implicitWidth: 150
                    placeholder: "Name"
                    onAccepted: page.addBang()
                }

                FieldInput {
                    id: newUrl

                    Layout.fillWidth: true
                    placeholder: "https://example.com/search?q=%s"
                    onAccepted: page.addBang()
                }

                PillButton {
                    toggled: true
                    icon: "add"
                    text: "Add"
                    onClicked: page.addBang()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: page.addError !== ""
                text: page.addError
                color: Appearance.accentColor
                font.pixelSize: 12
            }
        }
    }

    SettingGroup {
        visible: page.inner === ""
        title: "Built-in bangs"

        SettingCard {
            StyledText {
                Layout.fillWidth: true
                text: Object.keys(Search.builtinBangs).map(key => "!" + key + " " + Search.builtinBangs[key].name).join("   ·   ")
                wrapMode: Text.Wrap
                lineHeight: 1.3
                color: Appearance.mutedColor
                font.pixelSize: 13
            }
        }
    }

    SettingGroup {
        visible: page.inner === ""
        title: "History"

        SettingRow {
            icon: "history"
            title: "App ranking"
            description: page.launches > 0 ? page.launches + " launches remembered; apps you open most are listed first" : "Nothing remembered yet"

            PillButton {
                enabled: page.launches > 0
                text: "Reset"
                onClicked: {
                    Search.usageData = ({});
                    Search.saveUsage();
                }
            }
        }
    }

    // ------------------------------------------------------------ files and folders
    SettingGroup {
        visible: page.inner === "files"
        title: "Look in"

        Repeater {
            model: page.fileOpts.roots

            delegate: SettingRow {
                id: rootRow

                required property string modelData

                icon: modelData === "~" ? "home" : "folder"
                title: page.shortPath(modelData)
                description: modelData === "~" ? "Everything in it, down to the depth below" : "Searched on its own, down to the depth below"

                IconButton {
                    size: 32
                    iconSize: 18
                    icon: "delete"
                    onClicked: page.removeFrom("roots", rootRow.modelData)
                }
            }
        }

        SettingRow {
            visible: page.fileOpts.roots.length === 0
            icon: "folder_off"
            title: "No folders"
            description: "Files are not searched. Add a folder, or reset to the home folder."
        }

        SettingRow {
            icon: "create_new_folder"
            title: "Add a whole folder"
            description: "Type a path, or choose one"

            FieldInput {
                id: rootField

                implicitWidth: 220
                placeholder: "~/Documents"
                onAccepted: {
                    page.addTo("roots", rootField.text);
                    rootField.clear();
                }
            }

            PillButton {
                text: "Add"
                onClicked: {
                    page.addTo("roots", rootField.text);
                    rootField.clear();
                }
            }

            PillButton {
                icon: "folder_open"
                text: "Choose…"
                onClicked: {
                    page.pickFor = "roots";
                    folderDialog.open();
                }
            }
        }
    }

    SettingGroup {
        visible: page.inner === "files"
        title: "Leave out"

        Repeater {
            model: page.fileOpts.ignore

            delegate: SettingRow {
                id: ignoreRow

                required property string modelData

                icon: "folder_off"
                title: page.shortPath(modelData)
                description: modelData.startsWith("/") || modelData.startsWith("~") ? "This folder and everything in it" : "Any folder or file with this name, wherever it is"

                IconButton {
                    size: 32
                    iconSize: 18
                    icon: "delete"
                    onClicked: page.removeFrom("ignore", ignoreRow.modelData)
                }
            }
        }

        SettingRow {
            icon: "block"
            title: "Leave out a folder"
            description: "A name like node_modules, or a whole folder"

            FieldInput {
                id: ignoreField

                implicitWidth: 220
                placeholder: "node_modules"
                onAccepted: {
                    page.addTo("ignore", ignoreField.text);
                    ignoreField.clear();
                }
            }

            PillButton {
                text: "Add"
                onClicked: {
                    page.addTo("ignore", ignoreField.text);
                    ignoreField.clear();
                }
            }

            PillButton {
                icon: "folder_open"
                text: "Choose…"
                onClicked: {
                    page.pickFor = "ignore";
                    folderDialog.open();
                }
            }
        }
    }

    SettingGroup {
        visible: page.inner === "files"
        title: "Options"

        SettingRow {
            icon: "visibility"
            title: "Hidden files and folders"
            description: "Names that start with a dot, such as .config"

            ToggleSwitch {
                checked: page.fileOpts.hidden
                onToggled: on => Search.setFileOptions({
                        "hidden": on
                    })
            }
        }

        SettingRow {
            icon: "account_tree"
            title: "How deep to look"
            description: "Folders inside folders. Deeper finds more but takes longer."

            Dropdown {
                implicitWidth: 120
                model: [1, 2, 3, 4, 5, 6, 8, 10].map(n => ({
                            "label": n + (n === 1 ? " level" : " levels"),
                            "value": n
                        }))
                value: page.fileOpts.depth
                onSelected: v => Search.setFileOptions({
                        "depth": v
                    })
            }
        }

        SettingRow {
            icon: "format_list_numbered"
            title: "Results shown"
            description: "How many files the launcher lists"

            Dropdown {
                implicitWidth: 120
                model: [2, 3, 4, 6, 8].map(n => ({
                            "label": String(n),
                            "value": n
                        }))
                value: page.fileOpts.limit
                onSelected: v => Search.setFileOptions({
                        "limit": v
                    })
            }
        }
    }

    SettingGroup {
        visible: page.inner === "files"

        SettingRow {
            icon: "info"
            title: "No index is kept"
            description: "Names are looked up when you type, so results are always current and nothing runs in the background."
        }

        SettingRow {
            icon: "restart_alt"
            title: "Back to the defaults"
            description: "The home folder, 5 levels deep, no hidden files, leaving out node_modules and vendor, 4 results"

            PillButton {
                text: "Reset"
                onClicked: Search.resetFileOptions()
            }
        }
    }
}
