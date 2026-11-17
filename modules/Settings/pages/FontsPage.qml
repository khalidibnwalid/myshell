import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

SettingsPage {
    id: page

    readonly property var familyChoices: [
        {
            "label": "System default",
            "value": ""
        }
    ].concat(Fonts.families.map(f => ({
                "label": f,
                "value": f
            })))
    readonly property var used: Object.keys(Fonts.languages())
    readonly property var addable: Fonts.languageList.filter(l => page.used.indexOf(l.code) < 0).map(l => ({
                "label": l.name,
                "value": l.code,
                "description": Fonts.languageDefaults[l.code] ? "now " + Fonts.languageDefaults[l.code] : ""
            }))

    title: "Fonts"
    subtitle: "What apps use for text. The shell's own font is in Appearance"
    Component.onCompleted: Fonts.refresh()

    SettingGroup {
        title: "System fonts"

        Repeater {
            model: [
                {
                    "key": "sans",
                    "icon": "match_case",
                    "title": "Sans-serif",
                    "description": "Menus and most text in apps and websites"
                },
                {
                    "key": "serif",
                    "icon": "text_fields",
                    "title": "Serif",
                    "description": "Reading text that asks for a serif font"
                },
                {
                    "key": "mono",
                    "icon": "terminal",
                    "title": "Monospace",
                    "description": "Terminals and code editors that follow the system"
                }
            ]

            delegate: SettingRow {
                id: row

                required property var modelData

                icon: modelData.icon
                title: modelData.title
                description: modelData.description + (Fonts.systemDefaults[modelData.key] ? "  ·  now " + Fonts.systemDefaults[modelData.key] : "")

                Dropdown {
                    model: page.familyChoices
                    value: Fonts.get(row.modelData.key)
                    searchable: true
                    popupWidth: 300
                    onSelected: v => Fonts.set(row.modelData.key, v)
                }
            }
        }

        SettingRow {
            icon: "web_asset"
            title: "GTK app font"
            description: "Written to the GTK 3 and 4 settings, for apps such as Files and Firefox's menus · restart the app to see it"

            Dropdown {
                model: page.familyChoices
                value: Fonts.get("gtk")
                searchable: true
                popupWidth: 300
                onSelected: v => Fonts.set("gtk", v)
            }
        }
    }

    SettingGroup {
        title: "Font for each language"

        SettingRow {
            visible: page.used.length === 0
            icon: "translate"
            title: "No language is set here"
            description: "Add one, for example Arabic, to choose its font. The list shows what each language uses now, including from your own fontconfig files"
        }

        Repeater {
            model: page.used

            delegate: SettingRow {
                id: lang

                required property string modelData
                property var covering: []

                icon: "translate"
                title: Fonts.languageName(modelData)
                description: "Only fonts that have its letters are listed"
                Component.onCompleted: coverProc.running = true

                Process {
                    id: coverProc

                    command: ["fc-list", ":lang=" + lang.modelData, "family"]

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
                                out.push({
                                    "label": name,
                                    "value": name
                                });
                            }
                            out.sort((a, b) => a.label.toLowerCase() < b.label.toLowerCase() ? -1 : 1);
                            lang.covering = out;
                        }
                    }
                }

                Dropdown {
                    model: lang.covering
                    value: Fonts.languages()[lang.modelData]
                    placeholder: "Choose a font"
                    searchable: true
                    popupWidth: 300
                    onSelected: v => Fonts.setLanguage(lang.modelData, v)
                }

                IconButton {
                    icon: "close"
                    onClicked: Fonts.setLanguage(lang.modelData, null)
                }
            }
        }

        SettingRow {
            visible: page.addable.length > 0
            icon: "add"
            title: "Add a language"

            Dropdown {
                model: page.addable
                caption: "Add language"
                icon: "add"
                popupWidth: 260
                onSelected: code => {
                    // starts on what the language uses now, so adding it changes nothing yet
                    Fonts.setLanguage(code, Fonts.languageDefaults[code] || Fonts.get("sans") || Fonts.systemDefaults.sans || "");
                }
            }
        }
    }

    SettingGroup {
        title: "Preview"

        Repeater {
            model: [
                {
                    "text": "The quick brown fox jumps over the lazy dog 0123456789",
                    "family": Fonts.get("sans") || Fonts.systemDefaults.sans || "sans-serif"
                },
                {
                    "text": "The quick brown fox jumps over the lazy dog 0123456789",
                    "family": Fonts.get("serif") || Fonts.systemDefaults.serif || "serif"
                },
                {
                    "text": "{ } [ ] ( ) => != 0O 1lI  const x = 42;",
                    "family": Fonts.get("mono") || Fonts.systemDefaults.mono || "monospace"
                },
                {
                    "text": "نص تجريبي بالخط العربي المختار",
                    "family": Fonts.languages()["ar"] || Fonts.languageDefaults["ar"] || Fonts.get("sans") || Fonts.systemDefaults.sans || "sans-serif"
                }
            ]

            delegate: SettingCard {
                required property var modelData

                StyledText {
                    Layout.fillWidth: true
                    text: modelData.text
                    font.family: modelData.family
                    font.pixelSize: 18
                    wrapMode: Text.Wrap
                }

                StyledText {
                    text: modelData.family
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                }
            }
        }
    }
}
