pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The audio library: the tracks found in the audio folders (tags, length, cover), grouped into albums
// and artists, plus the favourites and the history. The scan (scan.sh) is incremental; the result
// is kept in library.json so the shell starts without scanning.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/quickshell/audio"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/quickshell/audio"
    readonly property string filePath: dir + "/library.json"

    property var folders: [home + "/Music"]
    // the library, and the files opened from elsewhere (kept for this session only)
    property var tracks: []
    property var adhoc: ({})
    property var byPath: ({})
    property var favorites: ({})
    // paths, newest first
    property var history: []
    property bool loaded: false
    property bool scanning: false
    property bool rescanQueued: false
    property var extraQueued: []
    readonly property var albums: buildAlbums(tracks)
    readonly property var artists: buildArtists(tracks)
    readonly property int favoriteCount: tracks.filter(t => favorites[t.path] === true).length

    signal pathsScanned(var paths)

    function url(path) {
        return path ? "file://" + String(path).split("/").map(encodeURIComponent).join("/") : "";
    }

    function cleanPath(path) {
        let p = String(path || "");
        if (p.startsWith("file://"))
            p = decodeURIComponent(p.slice(7));
        return p;
    }

    function baseName(path) {
        return String(path || "").split("/").pop();
    }

    function format(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(sec).padStart(2, "0");
    }

    function total(list) {
        let s = 0;
        for (const t of list)
            s += t.duration;
        const h = Math.floor(s / 3600);
        const m = Math.round((s % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : Math.max(1, m) + " min";
    }

    function lower(s) {
        return String(s || "").toLowerCase();
    }

    function compare(a, b) {
        const x = lower(a);
        const y = lower(b);
        return x < y ? -1 : (x > y ? 1 : 0);
    }

    // a record of scan.sh becomes a track
    function toTrack(fields) {
        const path = fields.path;
        const file = baseName(path);
        const folder = path.split("/").slice(-2, -1)[0] || "";
        const title = fields.title || file.replace(/\.[^.]+$/, "");
        const artist = fields.artist || "";
        const album = fields.album || "";
        const t = {
            "path": path,
            "title": title,
            "artist": artist,
            "album": album || folder,
            "tagged": album !== "",
            "albumArtist": fields.albumartist || "",
            "track": parseInt(fields.track) || 0,
            "disc": parseInt(fields.disc) || 1,
            "year": (String(fields.date || "").match(/\d{4}/) || [""])[0],
            "genre": fields.genre || "",
            "duration": parseFloat(fields.duration) || 0,
            "cover": fields.cover || "",
            "video": fields.video === "1",
            "added": parseInt(fields.mtime) || 0
        };
        t.hay = lower(title + " " + artist + " " + t.album + " " + t.genre);
        return t;
    }

    function parseRecords(text) {
        const out = [];
        for (const chunk of text.split("@@\n")) {
            if (chunk.trim() === "")
                continue;
            const fields = {};
            for (const line of chunk.split("\n")) {
                const eq = line.indexOf("=");
                if (eq > 0)
                    fields[line.slice(0, eq)] = line.slice(eq + 1);
            }
            if (fields.path)
                out.push(toTrack(fields));
        }
        return out;
    }

    function buildAlbums(list) {
        const map = {};
        const order = [];
        for (const t of list) {
            const key = lower(t.album) + "\u0001" + (t.tagged ? lower(t.albumArtist || t.artist) : "");
            let a = map[key];
            if (!a) {
                a = {
                    "key": key,
                    "title": t.album,
                    "artist": t.tagged ? (t.albumArtist || t.artist) : "",
                    "year": t.year,
                    "cover": "",
                    "tracks": []
                };
                map[key] = a;
                order.push(a);
            }
            if (a.cover === "" && t.cover !== "")
                a.cover = t.cover;
            if (a.artist !== "" && !t.albumArtist && t.artist !== a.artist)
                a.artist = "Various artists";
            a.tracks.push(t);
        }
        for (const a of order)
            a.tracks.sort((x, y) => (x.disc - y.disc) || (x.track - y.track) || compare(x.title, y.title));
        order.sort((x, y) => compare(x.title, y.title));
        return order;
    }

    function buildArtists(list) {
        const map = {};
        const order = [];
        for (const t of list) {
            const name = t.artist || t.albumArtist;
            const key = lower(name);
            let a = map[key];
            if (!a) {
                a = {
                    "key": key,
                    "name": name || "Unknown artist",
                    "cover": "",
                    "albums": {},
                    "tracks": []
                };
                map[key] = a;
                order.push(a);
            }
            if (a.cover === "" && t.cover !== "")
                a.cover = t.cover;
            a.albums[lower(t.album)] = true;
            a.tracks.push(t);
        }
        for (const a of order) {
            a.albumCount = Object.keys(a.albums).length;
            a.tracks.sort((x, y) => compare(x.album, y.album) || (x.disc - y.disc) || (x.track - y.track) || compare(x.title, y.title));
        }
        order.sort((x, y) => compare(x.name, y.name));
        return order;
    }

    function sorted(list, key) {
        const l = list.slice();
        if (key === "title")
            l.sort((a, b) => compare(a.title, b.title));
        else if (key === "artist")
            l.sort((a, b) => compare(a.artist, b.artist) || compare(a.album, b.album) || (a.disc - b.disc) || (a.track - b.track));
        else if (key === "album")
            l.sort((a, b) => compare(a.album, b.album) || (a.disc - b.disc) || (a.track - b.track) || compare(a.title, b.title));
        else if (key === "added")
            l.sort((a, b) => b.added - a.added);
        else if (key === "duration")
            l.sort((a, b) => b.duration - a.duration);
        return l;
    }

    function filter(list, query) {
        const words = lower(query).split(/\s+/).filter(w => w !== "");
        if (words.length === 0)
            return list;
        return list.filter(t => words.every(w => t.hay.includes(w)));
    }

    // the track of a path; a file that is not indexed yet shows its file name
    function track(path) {
        const have = byPath[path];
        if (have)
            return have;
        return toTrack({
            "path": path
        });
    }

    function rebuildIndex() {
        const map = {};
        for (const p in adhoc)
            map[p] = adhoc[p];
        for (const t of tracks)
            map[t.path] = t;
        byPath = map;
    }

    function isFavorite(path) {
        return favorites[path] === true;
    }

    function toggleFavorite(path) {
        const next = Object.assign({}, favorites);
        if (next[path])
            delete next[path];
        else
            next[path] = true;
        favorites = next;
        save();
    }

    function played(path) {
        history = [path].concat(history.filter(p => p !== path)).slice(0, 200);
        saveTimer.restart();
    }

    function clearHistory() {
        history = [];
        save();
    }

    function addFolder(path) {
        const p = cleanPath(path).replace(/\/+$/, "");
        if (p === "" || folders.indexOf(p) >= 0)
            return;
        folders = folders.concat([p]);
        save();
        refresh();
    }

    function removeFolder(path) {
        folders = folders.filter(f => f !== path);
        tracks = tracks.filter(t => !t.path.startsWith(path + "/"));
        rebuildIndex();
        save();
    }

    function inFolders(path) {
        return folders.some(f => path.startsWith(f + "/"));
    }

    // scans the folders again (only what changed is read); extra files or folders are indexed too
    function refresh(extra) {
        if (!loaded) {
            // asked for before the saved library was read: done as soon as it has been
            extraQueued = extraQueued.concat(extra || []);
            rescanQueued = true;
            return;
        }
        if (scanning && scanProc.running) {
            rescanQueued = true;
            if (extra)
                extraQueued = extraQueued.concat(extra);
            return;
        }
        scanning = true;
        scanProc.extra = extra || [];
        scanProc.command = [Quickshell.shellDir + "/apps/Audio/scripts/scan.sh", cacheDir].concat(folders, scanProc.extra);
        scanProc.running = true;
    }

    // indexes files or folders opened from anywhere ; pathsScanned() tells the paths found
    function scanPaths(paths) {
        refresh(paths);
    }

    function finishScan(text) {
        const found = parseRecords(text);
        const extra = scanProc.extra;
        const inLibrary = [];
        const ad = Object.assign({}, adhoc);
        for (const t of found) {
            if (inFolders(t.path))
                inLibrary.push(t);
            else
                ad[t.path] = t;
        }
        // a scan that printed nothing failed (a folder that is gone): keep what was known
        if (text.trim() !== "" || tracks.length === 0)
            tracks = inLibrary;
        adhoc = ad;
        rebuildIndex();
        scanning = false;
        save();
        if (extra.length > 0) {
            const hits = found.filter(t => extra.some(p => t.path === p || t.path.startsWith(p + "/"))).map(t => t.path);
            pathsScanned(hits);
        }
        if (rescanQueued) {
            rescanQueued = false;
            const more = extraQueued;
            extraQueued = [];
            refresh(more);
        }
    }

    function save() {
        if (!loaded)
            return;
        saveTimer.stop();
        writer.setText(JSON.stringify({
            "folders": folders,
            "favorites": Object.keys(favorites),
            "history": history,
            "tracks": tracks
        }));
    }

    function load() {
        if (!loaded && !loadProc.running)
            loadProc.running = true;
    }

    Timer {
        id: saveTimer

        interval: 1500
        onTriggered: root.save()
    }

    Process {
        id: loadProc

        command: ["sh", "-c", "mkdir -p \"$1\"; cat \"$1/library.json\" 2>/dev/null", "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                let data = {};
                try {
                    data = this.text.trim() === "" ? {} : JSON.parse(this.text);
                } catch (e) {
                    Quickshell.execDetached(["cp", root.filePath, root.filePath + ".corrupt"]);
                }
                if (Array.isArray(data.folders) && data.folders.length > 0)
                    root.folders = data.folders.map(String);
                if (Array.isArray(data.tracks))
                    root.tracks = data.tracks.filter(t => t && typeof t.path === "string" && typeof t.hay === "string");
                const fav = {};
                for (const p of data.favorites || [])
                    fav[p] = true;
                root.favorites = fav;
                root.history = Array.isArray(data.history) ? data.history.map(String) : [];
                root.rebuildIndex();
                root.loaded = true;
                // the first start has no library yet, and a file may have been asked for while loading
                if (root.tracks.length === 0 || root.rescanQueued) {
                    const more = root.extraQueued;
                    root.extraQueued = [];
                    root.rescanQueued = false;
                    root.refresh(more);
                }
            }
        }
    }

    Process {
        id: scanProc

        property var extra: []

        stdout: StdioCollector {
            onStreamFinished: root.finishScan(this.text)
        }
    }

    FileView {
        id: writer

        path: root.filePath
        preload: false
        atomicWrites: true
        printErrors: false
    }
}
