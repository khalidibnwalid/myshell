pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which app opens what, the way the system keeps it (mimeapps.list). Read with `gio mime`,
// changed with `xdg-mime`, so every other program sees the same choice.
Singleton {
    id: root

    readonly property var categories: [
        {
            "id": "browser",
            "title": "Web browser",
            "description": "Opens links and web pages",
            "icon": "language",
            "mimes": ["x-scheme-handler/https", "x-scheme-handler/http", "text/html"]
        },
        {
            "id": "files",
            "title": "File manager",
            "description": "Opens folders",
            "icon": "folder",
            "mimes": ["inode/directory"]
        },
        {
            "id": "mail",
            "title": "Email",
            "description": "Opens email addresses",
            "icon": "mail",
            "mimes": ["x-scheme-handler/mailto"]
        },
        {
            "id": "images",
            "title": "Images",
            "description": "PNG, JPEG, WebP and GIF",
            "icon": "image",
            "mimes": ["image/png", "image/jpeg", "image/webp", "image/gif"]
        },
        {
            "id": "video",
            "title": "Video",
            "description": "MP4, Matroska and WebM",
            "icon": "movie",
            "mimes": ["video/mp4", "video/x-matroska", "video/webm"]
        },
        {
            "id": "music",
            "title": "Music",
            "description": "MP3, FLAC, Ogg and WAV",
            "icon": "music_note",
            "mimes": ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav"]
        },
        {
            "id": "pdf",
            "title": "PDF documents",
            "description": "PDF files",
            "icon": "picture_as_pdf",
            "mimes": ["application/pdf"]
        },
        {
            "id": "text",
            "title": "Text and code",
            "description": "Plain text files",
            "icon": "description",
            "mimes": ["text/plain"]
        },
        {
            "id": "archives",
            "title": "Archives",
            "description": "ZIP, TAR and 7z",
            "icon": "folder_zip",
            "mimes": ["application/zip", "application/x-tar", "application/x-7z-compressed"]
        }
    ]

    // category id -> { current: "foo.desktop" | "", apps: ["foo.desktop", …] }
    property var byCategory: ({})
    property bool loaded: false

    function refresh() {
        readProc.running = true;
    }

    // the app for a category; "" when none is set
    function currentOf(id) {
        return byCategory[id] ? byCategory[id].current : "";
    }

    function appsOf(id) {
        return byCategory[id] ? byCategory[id].apps : [];
    }

    // the name and icon of an app from its desktop file id
    function entryOf(desktopId) {
        return DesktopEntries.byId(desktopId.replace(/\.desktop$/, "")) || DesktopEntries.byId(desktopId);
    }

    // sets it for every type of the category
    function set(id, desktopId) {
        const cat = categories.find(c => c.id === id);
        if (!cat)
            return;
        const next = Object.assign({}, byCategory);
        next[id] = Object.assign({}, byCategory[id] || ({}), {
            "current": desktopId
        });
        byCategory = next;
        Quickshell.execDetached(["xdg-mime", "default", desktopId].concat(cat.mimes));
        if (id === "browser")
            Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", desktopId]);
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer

        interval: 800
        onTriggered: root.refresh()
    }

    Process {
        id: readProc

        // for each category: its first type's default and the apps that can open it
        command: ["sh", "-c", "for c in \"$@\"; do id=${c%%=*}; mime=${c#*=}; echo \"CAT $id\"; LC_ALL=C gio mime \"$mime\" 2>/dev/null; done", "sh"].concat(root.categories.map(c => c.id + "=" + c.mimes[0]))

        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                let cur = null;
                let list = null;
                for (const raw of text.split(/\r?\n/)) {
                    if (raw.startsWith("CAT ")) {
                        cur = {
                            "current": "",
                            "apps": []
                        };
                        next[raw.slice(4).trim()] = cur;
                        continue;
                    }
                    if (!cur)
                        continue;
                    const m = raw.match(/^Default application for .*: (\S+\.desktop)\s*$/);
                    if (m) {
                        cur.current = m[1];
                    } else if (raw.startsWith("Registered applications") || raw.startsWith("Recommended applications")) {
                        list = cur.apps;
                    } else if (raw.startsWith("\t") && list) {
                        const id = raw.trim();
                        if (id.endsWith(".desktop") && list.indexOf(id) < 0)
                            list.push(id);
                    }
                }
                // keep the current one in the list even when gio does not register it
                for (const k in next) {
                    if (next[k].current !== "" && next[k].apps.indexOf(next[k].current) < 0)
                        next[k].apps.unshift(next[k].current);
                }
                root.byCategory = next;
                root.loaded = true;
            }
        }
    }

    Component.onCompleted: refresh()
}
