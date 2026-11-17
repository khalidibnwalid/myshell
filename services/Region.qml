pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Time zone, clock synchronisation, language and formats, as systemd (timedatectl,
// localectl) has them. Changes ask for administrator rights through polkit.
Singleton {
    id: root

    property string timezone: ""
    property bool ntp: true
    property bool synced: false
    property bool canNtp: true
    // [string]
    property var timezones: []
    // "en_US.UTF-8"
    property string language: ""
    // what dates, numbers, money, paper and units follow
    property string formats: ""
    // [{ label, value }] the locales that are generated on this computer
    property var locales: []
    property bool busy: false

    readonly property var languageNames: ({
            "en": "English",
            "ar": "Arabic",
            "fr": "French",
            "de": "German",
            "es": "Spanish",
            "it": "Italian",
            "pt": "Portuguese",
            "ru": "Russian",
            "tr": "Turkish",
            "zh": "Chinese",
            "ja": "Japanese",
            "ko": "Korean",
            "hi": "Hindi",
            "fa": "Persian",
            "ur": "Urdu",
            "nl": "Dutch",
            "pl": "Polish",
            "sv": "Swedish",
            "he": "Hebrew",
            "uk": "Ukrainian",
            "el": "Greek",
            "id": "Indonesian",
            "vi": "Vietnamese"
        })
    readonly property var formatKeys: ["LC_TIME", "LC_NUMERIC", "LC_MONETARY", "LC_PAPER", "LC_MEASUREMENT"]

    function refresh() {
        stateProc.running = true;
        localeProc.running = true;
        if (timezones.length === 0)
            zonesProc.running = true;
        if (locales.length === 0)
            availProc.running = true;
    }

    function run(cmd) {
        if (busy)
            return;
        actionProc.command = cmd;
        busy = true;
        actionProc.running = true;
    }

    function setTimezone(name) {
        if (name !== timezone)
            run(["timedatectl", "set-timezone", name]);
    }

    function setNtp(on) {
        run(["timedatectl", "set-ntp", on ? "true" : "false"]);
    }

    // "YYYY-MM-DD HH:MM", only while the automatic clock is off
    function setTime(text) {
        if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(text.trim()))
            run(["timedatectl", "set-time", text.trim() + ":00"]);
        else
            Quickshell.execDetached(["notify-send", "-a", "Date & time", "Use the form 2026-11-17 14:30"]);
    }

    // LANG and the formats are set together, because localectl replaces the whole list
    function setLocale(lang, fmt) {
        const args = ["localectl", "set-locale", "LANG=" + lang];
        for (let i = 0; i < formatKeys.length; i++) {
            if (fmt !== "" && fmt !== lang)
                args.push(formatKeys[i] + "=" + fmt);
        }
        run(args);
    }

    function setLanguage(value) {
        setLocale(value, formats);
    }

    function setFormats(value) {
        setLocale(language, value);
    }

    function labelFor(code) {
        const m = /^([a-z]+)_([A-Z]+)/.exec(code);
        if (!m)
            return code;
        return (languageNames[m[1]] || m[1]) + " (" + m[2] + ")  ·  " + code;
    }

    Process {
        id: stateProc

        command: ["timedatectl", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const eq = lines[i].indexOf("=");
                    if (eq < 0)
                        continue;
                    const k = lines[i].substring(0, eq);
                    const v = lines[i].substring(eq + 1);
                    if (k === "Timezone")
                        root.timezone = v;
                    else if (k === "NTP")
                        root.ntp = v === "yes";
                    else if (k === "CanNTP")
                        root.canNtp = v === "yes";
                    else if (k === "NTPSynchronized")
                        root.synced = v === "yes";
                }
            }
        }
    }

    Process {
        id: zonesProc

        command: ["timedatectl", "list-timezones"]

        stdout: StdioCollector {
            onStreamFinished: root.timezones = text.split("\n").filter(z => z !== "")
        }
    }

    Process {
        id: localeProc

        command: ["sh", "-c", "localectl status | sed -n '/System Locale/,/VC Keymap/p'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const re = /([A-Z_]+)=(\S+)/g;
                const vars = {};
                let m;
                while ((m = re.exec(text)) !== null)
                    vars[m[1]] = m[2];
                root.language = vars["LANG"] || "C";
                root.formats = vars["LC_TIME"] || root.language;
            }
        }
    }

    Process {
        id: availProc

        command: ["locale", "-a"]

        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const m = /^([a-z]+_[A-Z]+)\.utf-?8$/i.exec(lines[i]);
                    if (m)
                        rows.push({
                            "label": root.labelFor(m[1]),
                            "value": m[1] + ".UTF-8"
                        });
                }
                root.locales = rows;
            }
        }
    }

    Process {
        id: actionProc

        stderr: StdioCollector {
            id: actionErr
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "Date & time", "Could not change that", actionErr.text.trim() || "Administrator rights are needed"]);
            root.refresh();
        }
    }
}
