pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Emoji and text symbols for the picker in the clipboard menu.
// The list is assets/emoji.json (from the gemoji data, MIT); the recently used ones are kept
// in ~/.local/share/quickshell/emoji-recent.json.
Singleton {
    id: root

    property var categories: []
    property var recent: []
    property bool loaded: false
    property var all: []
    property var byChar: ({})
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/quickshell"
    readonly property int maxRecent: 32
    readonly property var hidden: ["\u{1F1EE}\u{1F1F1}", "\u{1F3F3}\uFE0F\u200D\u{1F308}", "\u{1F3F3}\uFE0F\u200D\u26A7\uFE0F"]

    function parse(text) { 
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return;
        }
        const cats = [];
        const all = [];
        const byChar = {};
        for (const c of data.categories) {
            const items = c.items.filter(it => root.hidden.indexOf(it[0]) < 0).map(it => ({
                        "char": it[0],
                        "name": it[1],
                        "words": it[2],
                        "hay": (it[1] + " " + it[2]).toLowerCase()
                    }));
            for (const it of items) {
                all.push(it);
                byChar[it.char] = it;
            }
            cats.push({
                "id": c.id,
                "icon": c.icon,
                "name": c.name,
                "items": items
            });
        }
        root.all = all;
        root.byChar = byChar;
        root.categories = cats;
        root.loaded = true;
    }

    // every word typed has to appear in the name or the keywords; names that start with it come first
    function search(query) {
        const words = query.toLowerCase().split(/\s+/).filter(w => w !== "");
        if (words.length === 0)
            return [];
        const first = [];
        const rest = [];
        for (const it of root.all) {
            if (!words.every(w => it.hay.indexOf(w) >= 0))
                continue;
            (it.name.startsWith(words[0]) ? first : rest).push(it);
        }
        return first.concat(rest).slice(0, 240);
    }

    function recentItems() {
        return root.recent.filter(c => root.hidden.indexOf(c) < 0).map(c => root.byChar[c] || {
                "char": c,
                "name": "",
                "words": "",
                "hay": ""
            });
    }

    function used(ch) {
        const list = [ch].concat(root.recent.filter(c => c !== ch)).slice(0, root.maxRecent);
        root.recent = list;
        writer.setText(JSON.stringify(list));
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dataDir])

    FileView {
        path: Quickshell.shellDir + "/assets/emoji.json"
        onLoaded: root.parse(text())
    }

    FileView {
        id: writer

        path: root.dataDir + "/emoji-recent.json"
        atomicWrites: true
        // reads the saved list once at the start; a missing file is the first run
        onLoaded: {
            try {
                const v = JSON.parse(text());
                if (Array.isArray(v))
                    root.recent = v.slice(0, root.maxRecent);
            } catch (e) {}
        }
    }
}
