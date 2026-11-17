pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Io

// System fonts: the families apps get for sans-serif, serif and monospace, a font for each
// language, and the GTK interface font. Chosen fonts are kept in Config.fonts and written to
// our own fontconfig file, so the user's own fontconfig files are never edited.
Singleton {
    id: root

    readonly property string confFile: Quickshell.env("HOME") + "/.config/fontconfig/conf.d/99-quickshell-fonts.conf"
    readonly property var generics: [
        {
            "key": "sans",
            "name": "sans-serif"
        },
        {
            "key": "serif",
            "name": "serif"
        },
        {
            "key": "mono",
            "name": "monospace"
        }
    ]
    // code is what fontconfig calls the language
    readonly property var languageList: [
        {
            "code": "ar",
            "name": "Arabic"
        },
        {
            "code": "he",
            "name": "Hebrew"
        },
        {
            "code": "fa",
            "name": "Persian"
        },
        {
            "code": "ur",
            "name": "Urdu"
        },
        {
            "code": "hi",
            "name": "Hindi"
        },
        {
            "code": "th",
            "name": "Thai"
        },
        {
            "code": "ru",
            "name": "Russian"
        },
        {
            "code": "el",
            "name": "Greek"
        },
        {
            "code": "ja",
            "name": "Japanese"
        },
        {
            "code": "ko",
            "name": "Korean"
        },
        {
            "code": "zh-cn",
            "name": "Chinese (Simplified)"
        },
        {
            "code": "zh-tw",
            "name": "Chinese (Traditional)"
        }
    ]

    // [string] every installed family
    property var families: []
    // what the system picks today for each generic name: { sans: "Tajawal", ... }
    property var systemDefaults: ({})
    // what each language gets today, from any fontconfig file: { ar: "Tajawal", ... }
    property var languageDefaults: ({})

    function refresh() {
        if (families.length === 0)
            listProc.running = true;
        defaultsProc.running = true;
        langDefaultsProc.running = true;
    }

    function get(key) {
        return Config.fonts?.[key] ?? "";
    }

    function languages() {
        return Config.fonts?.languages ?? {};
    }

    function languageName(code) {
        for (let i = 0; i < languageList.length; i++) {
            if (languageList[i].code === code)
                return languageList[i].name;
        }
        return code;
    }

    function set(key, value) {
        Config.setIn("fonts", key, value);
        apply();
    }

    function setLanguage(code, family) {
        const langs = JSON.parse(JSON.stringify(languages()));
        if (family === null)
            delete langs[code];
        else
            langs[code] = family;
        Config.setIn("fonts", "languages", langs);
        apply();
    }

    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function buildConf() {
        let x = "<?xml version=\"1.0\"?>\n<!DOCTYPE fontconfig SYSTEM \"urn:fontconfig:fonts.dtd\">\n<fontconfig>\n";
        x += "  <!-- written by the Quickshell Settings window; changes here are overwritten -->\n";
        // language rules come first: after a generic family's own alias they lose
        const langs = languages();
        for (const code of Object.keys(langs)) {
            if (!langs[code])
                continue;
            for (let i = 0; i < generics.length; i++) {
                // for text an app says is in this language, and as a fallback for characters the main font lacks
                x += "  <match target=\"pattern\"><test name=\"lang\" compare=\"contains\"><string>" + esc(code) + "</string></test><test name=\"family\"><string>" + generics[i].name + "</string></test><edit name=\"family\" mode=\"prepend\" binding=\"strong\"><string>" + esc(langs[code]) + "</string></edit></match>\n";
                x += "  <match target=\"pattern\"><test name=\"family\"><string>" + generics[i].name + "</string></test><edit name=\"family\" mode=\"append\"><string>" + esc(langs[code]) + "</string></edit></match>\n";
            }
        }
        for (let i = 0; i < generics.length; i++) {
            const f = get(generics[i].key);
            if (f !== "")
                x += "  <alias binding=\"same\"><family>" + generics[i].name + "</family><prefer><family>" + esc(f) + "</family></prefer></alias>\n";
        }
        return x + "</fontconfig>\n";
    }

    // keeps the size already in the GTK files and only changes the family
    readonly property string applyScript: "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1\"; "
        + "g=\"$3\"; if [ -n \"$g\" ]; then "
        + "for f in \"$HOME/.config/gtk-3.0/settings.ini\" \"$HOME/.config/gtk-4.0/settings.ini\"; do [ -f \"$f\" ] && grep -q '^gtk-font-name=' \"$f\" && "
        + "awk -v n=\"$g\" '/^gtk-font-name=/{s=$NF; if (s !~ /^[0-9.]+$/) s=11; print \"gtk-font-name=\" n \" \" s; next} 1' \"$f\" > \"$f.tmp\" && mv \"$f.tmp\" \"$f\"; done; "
        + "command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface font-name \"$g 11\" 2>/dev/null; fi; "
        + "m=\"$4\"; [ -n \"$m\" ] && command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface monospace-font-name \"$m 11\" 2>/dev/null; "
        + "fc-cache >/dev/null 2>&1; exit 0"

    function apply() {
        applyProc.command = ["sh", "-c", applyScript, "sh", confFile, buildConf(), get("gtk"), get("mono")];
        applyProc.running = true;
        defaultsTimer.restart();
    }

    Timer {
        id: defaultsTimer

        interval: 600
        onTriggered: {
            defaultsProc.running = true;
            langDefaultsProc.running = true;
        }
    }

    Process {
        id: applyProc
    }

    Process {
        id: listProc

        command: ["fc-list", ":", "family"]

        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const name = lines[i].split(",")[0].trim();
                    if (name === "" || seen[name] || name.startsWith("Material Symbols"))
                        continue;
                    seen[name] = true;
                    out.push(name);
                }
                out.sort((a, b) => a.toLowerCase() < b.toLowerCase() ? -1 : 1);
                root.families = out;
            }
        }
    }

    Process {
        id: langDefaultsProc

        command: ["sh", "-c", "for l; do printf '%s=%s\\n' \"$l\" \"$(fc-match -f '%{family[0]}' \"sans-serif:lang=$l\")\"; done", "sh"].concat(root.languageList.map(l => l.code))

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const eq = lines[i].indexOf("=");
                    if (eq > 0)
                        out[lines[i].substring(0, eq)] = lines[i].substring(eq + 1);
                }
                root.languageDefaults = out;
            }
        }
    }

    Process {
        id: defaultsProc

        command: ["sh", "-c", "for g in sans-serif serif monospace; do fc-match -f '%{family[0]}\\n' $g; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.systemDefaults = {
                    "sans": l[0] || "",
                    "serif": l[1] || "",
                    "mono": l[2] || ""
                };
            }
        }
    }
}
