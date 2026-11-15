pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Word suggestions while typing in any app.
//
// A small helper (helpers/ime/qs-ime.c, built on first use) registers as the Wayland
// input method. It reports the text before the cursor of the focused text field and
// replaces the word there on request. This service turns that text into suggestions
// from per-language word lists, which are downloaded the first time a language is
// used, and keeps the state of the popup:
//
//   Tab / Shift+Tab   put the next / previous suggestion into the text
//   Escape            close the popup and put back what was typed
//
// Nothing that is typed leaves the computer; the only download is the public word list.
Singleton {
    id: root

    readonly property bool enabled: Config.autocomplete.enabled
    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/quickshell/ime"
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/quickshell/autocomplete"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/quickshell"
    readonly property string listUrl: "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/%1/%1_full.txt"

    // "off", "building", "starting", "ready", "unavailable" (another input method runs),
    // "unsupported" (compositor), "failed" (build or helper error)
    property string status: "off"
    property string problem: ""
    // a text field that can be completed in has the focus
    property bool fieldActive: false

    // apps to stay out of (terminals: Tab belongs to the shell there). Each entry is
    // matched anywhere in the window class, ignoring case.
    readonly property var excluded: Config.autocomplete.excludeApps.split(",").map(a => a.trim().toLowerCase()).filter(Boolean)
    readonly property string activeClass: Hyprland.activeToplevel?.wayland?.appId || Hyprland.activeToplevel?.lastIpcObject?.class || ""
    readonly property bool muted: {
        const cls = activeClass.toLowerCase();
        return cls !== "" && excluded.some(entry => cls.includes(entry));
    }

    onMutedChanged: {
        if (status === "ready")
            helper.write(muted ? "mute 1\n" : "mute 0\n");
        if (muted)
            hide();
    }

    // --- languages ----------------------------------------------------------
    // xkb layout code -> word list language
    readonly property var layoutLanguages: ({
        "us": "en", "gb": "en", "au": "en", "ca": "en", "ie": "en", "nz": "en", "za": "en", "in": "en",
        "ara": "ar", "iq": "ar", "sy": "ar", "ma": "ar", "dz": "ar", "eg": "ar",
        "ru": "ru", "ua": "uk", "bg": "bg", "rs": "sr", "mk": "mk", "kz": "kk",
        "fr": "fr", "be": "fr", "de": "de", "at": "de", "ch": "de", "es": "es", "latam": "es", "it": "it",
        "pt": "pt", "br": "pt_br", "nl": "nl", "pl": "pl", "cz": "cs", "sk": "sk", "hu": "hu", "ro": "ro",
        "se": "sv", "no": "no", "dk": "da", "fi": "fi", "is": "is", "ee": "et", "lv": "lv", "lt": "lt",
        "gr": "el", "tr": "tr", "il": "he", "ir": "fa", "pk": "ur", "id": "id", "my": "ms", "vn": "vi",
        "hr": "hr", "si": "sl", "al": "sq", "ge": "ka", "am": "hy", "th": "th", "kr": "ko"
    })
    readonly property var languageNames: ({
        "en": "English", "ar": "Arabic", "ru": "Russian", "uk": "Ukrainian", "bg": "Bulgarian", "sr": "Serbian",
        "mk": "Macedonian", "kk": "Kazakh", "fr": "French", "de": "German", "es": "Spanish", "it": "Italian",
        "pt": "Portuguese", "pt_br": "Portuguese (Brazil)", "nl": "Dutch", "pl": "Polish", "cs": "Czech",
        "sk": "Slovak", "hu": "Hungarian", "ro": "Romanian", "sv": "Swedish", "no": "Norwegian", "da": "Danish",
        "fi": "Finnish", "is": "Icelandic", "et": "Estonian", "lv": "Latvian", "lt": "Lithuanian", "el": "Greek",
        "tr": "Turkish", "he": "Hebrew", "fa": "Persian", "ur": "Urdu", "id": "Indonesian", "ms": "Malay",
        "vi": "Vietnamese", "hr": "Croatian", "sl": "Slovenian", "sq": "Albanian", "ka": "Georgian",
        "hy": "Armenian", "th": "Thai", "ko": "Korean"
    })
    // language -> script, for telling which word list a typed word belongs to
    readonly property var languageScripts: ({
        "ar": "arabic", "fa": "arabic", "ur": "arabic",
        "ru": "cyrillic", "uk": "cyrillic", "bg": "cyrillic", "sr": "cyrillic", "mk": "cyrillic", "kk": "cyrillic",
        "el": "greek", "he": "hebrew", "ka": "georgian", "hy": "armenian", "th": "thai", "ko": "hangul"
    })

    // the languages of the keyboard layouts, in layout order, without repeats
    readonly property var wantedLanguages: {
        const list = [];
        for (const layout of Keyboard.layouts) {
            const lang = layoutLanguages[layout.code];
            if (lang && list.indexOf(lang) < 0)
                list.push(lang);
        }
        return list;
    }
    // the language of the layout in use
    readonly property string currentLanguage: {
        const layout = Keyboard.layouts[Keyboard.activeIndex];
        return layout ? (layoutLanguages[layout.code] || "") : "";
    }

    // language -> { index: { "he": ["hello", …] }, count }   (words in frequency order)
    property var dictionaries: ({})
    // language -> "missing" | "downloading" | "loading" | "ready" | "failed"
    property var languageStates: ({})
    // language -> { word: times completed }
    property var learned: ({})

    function languageName(lang) {
        return languageNames[lang] || lang.toUpperCase();
    }

    function languageState(lang) {
        return languageStates[lang] || "missing";
    }

    function wordCount(lang) {
        return dictionaries[lang] ? dictionaries[lang].count : 0;
    }

    function setLanguageState(lang, state) {
        const next = Object.assign({}, languageStates);
        next[lang] = state;
        languageStates = next;
    }

    function listPath(lang) {
        return dataDir + "/" + lang + "_200k.txt";
    }

    // loads the word list of a language, downloading it first when it is not there yet
    function ensureLanguage(lang, forceDownload) {
        if (!lang)
            return;
        const state = languageState(lang);
        if (state === "downloading" || state === "loading" || (state === "ready" && !forceDownload))
            return;
        setLanguageState(lang, "loading");
        const proc = listProc.createObject(root, {
            "lang": lang
        });
        // prints "ok" and the words (most frequent first), or "fail"
        // the full list is big and noisy: keep the 200 000 most frequent words that were seen at least 15 times
        const fetch = "mkdir -p \"$1\" && { [ -s \"$2\" ] && [ \"$4\" != force ] || { curl -fsSL --max-time 300 -o \"$2.full\" \"$3\" && awk 'NR <= 200000 && $2 >= 15' \"$2.full\" > \"$2.part\" && mv \"$2.part\" \"$2\" && rm -f \"$2.full\"; }; }";
        proc.command = ["sh", "-c", "if " + fetch + "; then echo ok; cut -d' ' -f1 \"$2\"; else rm -f \"$2.part\" \"$2.full\"; echo fail; fi", "sh", dataDir, listPath(lang), listUrl.arg(lang), forceDownload ? "force" : ""];
        proc.running = true;
        // a download takes a moment; a list that is already on disk loads at once
        downloadCheck.createObject(root, {
            "lang": lang
        });
    }

    function loadWords(lang, text) {
        const lines = text.split("\n");
        if (lines[0] !== "ok") {
            setLanguageState(lang, "failed");
            return;
        }
        const index = {};
        const seen = {};
        let count = 0;
        const wordPattern = wholeWord;
        // Arabic vowel marks and the stretching dash are rarely typed: "مرحباً" and "مرحبا" are one word
        const marks = /[\u064B-\u065F\u0670\u0640]/g;
        for (let i = 1; i < lines.length; i++) {
            const word = lines[i].replace(marks, "");
            if (word.length < 2 || seen[word] || !wordPattern.test(word))
                continue;
            seen[word] = true;
            const key = word.substring(0, 2).toLowerCase();
            if (!index[key])
                index[key] = [];
            index[key].push(word);
            count++;
        }
        const next = Object.assign({}, dictionaries);
        next[lang] = {
            "index": index,
            "count": count
        };
        dictionaries = next;
        setLanguageState(lang, count > 0 ? "ready" : "failed");
    }

    function removeLanguage(lang) {
        const next = Object.assign({}, dictionaries);
        delete next[lang];
        dictionaries = next;
        setLanguageState(lang, "missing");
        Quickshell.execDetached(["rm", "-f", listPath(lang)]);
    }

    // What counts as part of a word. Spelled out as ranges, because the shell's JavaScript
    // has no \p{L}: Latin, Greek, Cyrillic, Armenian, Hebrew, Arabic (with its marks),
    // Thai, Georgian, Hangul, and the apostrophes inside words like "don't".
    readonly property string letters: "A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u024F\u0370-\u03FF\u0400-\u052F\u0531-\u0587\u05D0-\u05EA\u0620-\u065F\u066E-\u06D3\u06FA-\u06FF\u0E01-\u0E4E\u10A0-\u10FF\uAC00-\uD7AF'\u2019"
    readonly property var wholeWord: new RegExp("^[" + letters + "]+$")
    readonly property var wordAtEnd: new RegExp("[" + letters + "]+$")

    // --- suggestions --------------------------------------------------------
    property var suggestions: []
    // the suggestion that is in the text right now, -1 while only the typed letters are
    property int index: -1
    property bool visible: false
    // what was typed of the current word, and its language
    property string prefix: ""
    // the word before it (lower case), which the suggestions are tuned to
    property string previousWord: ""
    property string wordLanguage: ""
    // the text that the last Tab put in place of the prefix ("" = none)
    property string applied: ""
    // a replacement is on its way: the field reports it in one or two steps
    property string expecting: ""
    property double expectingUntil: 0
    // Escape was pressed for this word: stay closed until the next one
    property bool dismissed: false
    // where the popup goes: screen-global point, and whether it grows upwards from it
    property real anchorX: 0
    property real anchorY: 0
    property bool anchorAbove: false
    // "caret" placement: the helper draws the list next to the text cursor (only an input
    // method's own surface is put there by the compositor), in the shell's colours
    readonly property bool drawnByHelper: Config.autocomplete.position === "caret"
    readonly property string styleLine: "style " + [Qt.alpha(Appearance.bgColor, Math.max(0.92, Appearance.panelAlpha)), Appearance.fgColor, Appearance.accentColor, Appearance.accentContrastColor, Appearance.mutedColor, Appearance.outlineColor].map(c => String(c)).join(" ") + " 15 " + Appearance.fontFamily

    function syncDrawn() {
        if (status !== "ready")
            return;
        if (visible && drawnByHelper && suggestions.length > 0)
            helper.write("draw " + index + " " + charCount(prefix) + " " + suggestions.join("\t") + "\n");
        else
            helper.write("undraw\n");
    }

    onStyleLineChanged: {
        if (status === "ready") {
            helper.write(styleLine + "\n");
            syncDrawn();
        }
    }
    onIndexChanged: Qt.callLater(syncDrawn)
    onSuggestionsChanged: Qt.callLater(syncDrawn)
    onDrawnByHelperChanged: Qt.callLater(syncDrawn)

    readonly property bool rightToLeft: languageScripts[wordLanguage] === "arabic" || languageScripts[wordLanguage] === "hebrew"

    function scriptOf(text) {
        const c = text.codePointAt(0);
        if (c >= 0x0600 && c <= 0x06FF || c >= 0x0750 && c <= 0x077F || c >= 0xFB50 && c <= 0xFDFF || c >= 0xFE70 && c <= 0xFEFF)
            return "arabic";
        if (c >= 0x0400 && c <= 0x052F)
            return "cyrillic";
        if (c >= 0x0370 && c <= 0x03FF)
            return "greek";
        if (c >= 0x0590 && c <= 0x05FF)
            return "hebrew";
        if (c >= 0x10A0 && c <= 0x10FF)
            return "georgian";
        if (c >= 0x0530 && c <= 0x058F)
            return "armenian";
        if (c >= 0x0E00 && c <= 0x0E7F)
            return "thai";
        if (c >= 0xAC00 && c <= 0xD7AF)
            return "hangul";
        return "latin";
    }

    // the word list for a typed word: the layout's language when the script fits,
    // else another loaded language with that script
    function languageFor(word) {
        const script = scriptOf(word);
        const fits = lang => (languageScripts[lang] || "latin") === script;
        if (currentLanguage !== "" && fits(currentLanguage))
            return currentLanguage;
        return wantedLanguages.find(fits) || "";
    }

    function charCount(text) {
        let n = 0;
        for (const ch of text)
            n++;
        return n;
    }

    function utf8Length(text) {
        let bytes = 0;
        for (const ch of text) {
            const c = ch.codePointAt(0);
            bytes += c < 0x80 ? 1 : (c < 0x800 ? 2 : (c < 0x10000 ? 3 : 4));
        }
        return bytes;
    }

    function lookup(lang, typed, previous) {
        const dict = dictionaries[lang];
        if (!dict)
            return [];
        const lower = typed.toLowerCase();
        const bucket = dict.index[lower.substring(0, 2)] || [];
        const limit = Math.max(1, Config.autocomplete.maxSuggestions);
        const allCaps = typed.length > 1 && typed === typed.toUpperCase() && typed !== lower;
        // keep the letters as typed and add the rest of the word
        const shape = word => typed + (allCaps ? word.substring(typed.length).toUpperCase() : word.substring(typed.length));
        const found = [];
        const taken = {};
        const add = word => {
            const text = shape(word);
            if (!taken[text]) {
                taken[text] = true;
                found.push(text);
            }
        };
        // words completed before come first, most used first. Learned entries are single
        // words, or "previous word" + " " + "word" for what followed that word before.
        const mine = Config.autocomplete.learn ? (learned[lang] || {}) : {};
        const keys = Object.keys(mine);
        if (previous !== "") {
            const lead = previous + " ";
            keys.filter(k => k.startsWith(lead)).map(k => k.substring(lead.length)).filter(w => w.length > lower.length && w.toLowerCase().startsWith(lower)).sort((a, b) => mine[lead + b] - mine[lead + a]).slice(0, limit).forEach(add);
        }
        keys.filter(k => k.indexOf(" ") < 0 && k.length > lower.length && k.toLowerCase().startsWith(lower)).sort((a, b) => mine[b] - mine[a]).slice(0, limit).forEach(add);
        for (let i = 0; i < bucket.length && found.length < limit; i++) {
            const word = bucket[i];
            if (word.length > lower.length && word.toLowerCase().startsWith(lower))
                add(word);
        }
        return found.slice(0, limit);
    }

    function hide() {
        if (visible)
            visible = false;
        suggestions = [];
        index = -1;
    }

    // the word that was being cycled is final now: remember it
    function finishCycle() {
        if (applied !== "" && Config.autocomplete.learn && wordLanguage !== "") {
            const word = applied.trim();
            const all = Object.assign({}, learned);
            const mine = Object.assign({}, all[wordLanguage] || {});
            mine[word] = (mine[word] || 0) + 1;
            if (previousWord !== "") {
                const pair = previousWord + " " + word.toLowerCase();
                mine[pair] = (mine[pair] || 0) + 1;
            }
            all[wordLanguage] = mine;
            learned = all;
            saveLearned.restart();
        }
        applied = "";
        expecting = "";
    }

    // the helper reports the text before the cursor
    function onText(text) {
        if (muted) {
            hide();
            return;
        }
        if (expecting !== "") {
            if (text.endsWith(expecting)) {
                // our own replacement arrived: the popup stays as it is
                expecting = "";
                return;
            }
            if (Date.now() < expectingUntil)
                return;
            expecting = "";
        }
        if (applied !== "" && text.endsWith(applied))
            return;

        // the user typed, deleted or moved: start over with the word at the cursor
        finishCycle();
        const m = text.match(wordAtEnd);
        const word = m ? m[0] : "";
        const before = m ? text.substring(0, m.index) : text;
        const prev = before.match(new RegExp("([" + letters + "]+)[\\s,;:]*$"));
        previousWord = prev ? prev[1].toLowerCase() : "";
        if (word === "") {
            dismissed = false;
            prefix = "";
            hide();
            return;
        }
        if (dismissed && word.startsWith(prefix)) {
            // still the word Escape was pressed on
            prefix = word;
            return;
        }
        dismissed = false;
        prefix = word;
        if (word.length < Math.max(1, Config.autocomplete.minChars)) {
            hide();
            return;
        }
        const lang = languageFor(word);
        wordLanguage = lang;
        if (lang === "") {
            hide();
            return;
        }
        if (!dictionaries[lang]) {
            ensureLanguage(lang, false);
            hide();
            return;
        }
        const found = lookup(lang, word, previousWord);
        if (found.length === 0) {
            hide();
            return;
        }
        suggestions = found;
        index = -1;
        if (!visible)
            place();
    }

    // puts suggestion i in place of what stands there now
    function choose(i) {
        if (i < 0 || i >= suggestions.length || status !== "ready")
            return;
        const current = applied !== "" ? applied : prefix;
        const next = suggestions[i] + (Config.autocomplete.addSpace ? " " : "");
        index = i;
        applied = next;
        expecting = next;
        expectingUntil = Date.now() + 400;
        helper.write("replace " + utf8Length(current) + " " + charCount(current) + " " + next + "\n");
    }

    function onKey(key) {
        if (!visible || suggestions.length === 0)
            return;
        const n = suggestions.length;
        if (key === "tab") {
            choose((index + 1) % n);
        } else if (key === "shifttab") {
            choose(index <= 0 ? n - 1 : index - 1);
        } else if (key === "esc") {
            if (applied !== "") {
                // put back what was typed
                expecting = prefix;
                expectingUntil = Date.now() + 400;
                helper.write("replace " + utf8Length(applied) + " " + charCount(applied) + " " + prefix + "\n");
                applied = "";
            }
            dismissed = true;
            hide();
        }
    }

    // works out where the popup goes, then shows it
    function place() {
        if (drawnByHelper)
            visible = true; // the compositor puts it at the text cursor
        else
            placeProc.running = true;
    }

    onVisibleChanged: {
        if (status === "ready")
            helper.write(visible ? "popup 1\n" : "popup 0\n");
        syncDrawn();
    }

    // --- the helper ---------------------------------------------------------
    function start() {
        if (status === "building" || status === "starting" || status === "ready")
            return;
        problem = "";
        status = "building";
        buildProc.running = true;
    }

    function stop() {
        retry.stop();
        hide();
        fieldActive = false;
        if (helper.running) {
            helper.write("quit\n");
            helper.running = false;
        }
        status = "off";
    }

    function handleLine(line) {
        let event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (event.e) {
        case "ready":
            status = "ready";
            helper.write(styleLine + "\n");
            if (muted)
                helper.write("mute 1\n");
            for (const lang of wantedLanguages)
                ensureLanguage(lang, false);
            break;
        case "unavailable":
            status = "unavailable";
            problem = "Another input method (fcitx5, ibus…) is running. Only one can be active.";
            break;
        case "unsupported":
            status = "unsupported";
            problem = "The compositor does not offer the input method protocol.";
            break;
        case "active":
            fieldActive = event.v;
            if (!event.v) {
                finishCycle();
                prefix = "";
                dismissed = false;
                hide();
            }
            break;
        case "text":
            onText(event.t);
            break;
        case "key":
            onKey(event.k);
            break;
        }
    }

    onEnabledChanged: enabled ? start() : stop()
    Component.onCompleted: {
        loadLearned.running = true;
        if (enabled)
            start();
    }
    // a layout was added or switched to: have its word list ready
    onWantedLanguagesChanged: {
        if (status === "ready") {
            for (const lang of wantedLanguages)
                ensureLanguage(lang, false);
        }
    }

    Process {
        id: buildProc

        command: [Quickshell.shellDir + "/helpers/ime/build.sh", root.cacheDir]

        stderr: StdioCollector {
            id: buildErrors
        }

        onExited: code => {
            if (!root.enabled)
                return;
            if (code !== 0) {
                root.status = "failed";
                root.problem = "Couldn't build the helper. It needs a C compiler, wayland-scanner and the wayland and xkbcommon headers.\n" + buildErrors.text.trim().split("\n").slice(-3).join("\n");
                return;
            }
            root.status = "starting";
            helper.running = true;
        }
    }

    Process {
        id: helper

        command: [root.cacheDir + "/qs-ime"]
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }

        onExited: code => {
            root.hide();
            root.fieldActive = false;
            if (!root.enabled || root.status === "off" || root.status === "unavailable" || root.status === "unsupported")
                return;
            // it should keep running: try again in a moment, a few times
            root.status = "failed";
            root.problem = "The helper stopped (exit code " + code + ").";
            if (retry.attempts < 3) {
                retry.attempts++;
                retry.restart();
            }
        }
    }

    Timer {
        id: retry

        property int attempts: 0

        interval: 4000
        onTriggered: {
            if (root.enabled && root.status === "failed")
                root.start();
        }
    }

    // --- placement ----------------------------------------------------------
    Process {
        id: placeProc

        command: Config.autocomplete.position === "window" ? ["hyprctl", "activewindow", "-j"] : ["hyprctl", "cursorpos"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.suggestions.length === 0)
                    return;
                if (Config.autocomplete.position === "window") {
                    try {
                        const win = JSON.parse(text);
                        root.anchorX = win.at[0] + 20;
                        root.anchorY = win.at[1] + win.size[1] - 20;
                        root.anchorAbove = true;
                    } catch (e) {
                        root.anchorAbove = false;
                    }
                } else {
                    const m = text.match(/(-?\d+),\s*(-?\d+)/);
                    // a little below and to the right of the pointer, so it does not cover the hot spot
                    root.anchorX = m ? parseInt(m[1]) + 14 : 0;
                    root.anchorY = m ? parseInt(m[2]) + 20 : 0;
                    root.anchorAbove = false;
                }
                root.visible = true;
            }
        }
    }

    // --- word lists ---------------------------------------------------------
    Component {
        id: listProc

        Process {
            id: proc

            required property string lang

            stdout: StdioCollector {
                onStreamFinished: {
                    root.loadWords(proc.lang, text);
                    proc.destroy();
                }
            }
        }
    }

    // shows "downloading" for a list that is not loaded after a moment
    Component {
        id: downloadCheck

        Timer {
            required property string lang

            interval: 700
            running: true
            onTriggered: {
                if (root.languageState(lang) === "loading")
                    root.setLanguageState(lang, "downloading");
                destroy();
            }
        }
    }

    // --- learned words ------------------------------------------------------
    function forgetLearned() {
        learned = ({});
        saveLearned.restart();
    }

    Process {
        id: loadLearned

        command: ["cat", root.stateDir + "/autocomplete.json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data && typeof data === "object")
                        root.learned = data;
                } catch (e) {
                }
            }
        }
    }

    Timer {
        id: saveLearned

        interval: 1500
        onTriggered: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/autocomplete.json\"", "sh", root.stateDir, JSON.stringify(root.learned)])
    }

    // qs ipc call autocomplete toggle | enable | disable | status
    IpcHandler {
        function toggle(): void {
            Config.autocomplete.enabled = !Config.autocomplete.enabled;
        }

        function enable(): void {
            Config.autocomplete.enabled = true;
        }

        function disable(): void {
            Config.autocomplete.enabled = false;
        }

        function status(): string {
            return JSON.stringify({
                "status": root.status,
                "problem": root.problem,
                "fieldActive": root.fieldActive,
                "app": root.activeClass,
                "muted": root.muted,
                "visible": root.visible,
                "prefix": root.prefix,
                "language": root.wordLanguage,
                "suggestions": root.suggestions,
                "index": root.index,
                "languages": root.wantedLanguages.map(l => l + ":" + root.languageState(l) + ":" + root.wordCount(l))
            });
        }

        target: "autocomplete"
    }
}
