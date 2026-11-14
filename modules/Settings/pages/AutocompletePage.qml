import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

SettingsPage {
    id: page

    readonly property bool on: Config.autocomplete.enabled
    readonly property bool broken: Autocomplete.status === "unavailable" || Autocomplete.status === "unsupported" || Autocomplete.status === "failed"
    // layouts that have no word list to offer
    readonly property var unsupportedLayouts: Keyboard.layouts.filter(l => !Autocomplete.layoutLanguages[l.code]).map(l => l.name)
    readonly property int learnedCount: Object.values(Autocomplete.learned).reduce((sum, words) => sum + Object.keys(words).length, 0)

    // --- blocked apps: entries are matched anywhere in a window's class, ignoring case ---
    readonly property var blocked: Autocomplete.excluded
    // the apps with a window open that are not blocked yet, for the "Block app" list
    readonly property var blockable: {
        const seen = {};
        const list = [];
        for (const t of Hyprland.toplevels.values) {
            const cls = t.wayland?.appId || t.lastIpcObject?.class || "";
            const key = cls.toLowerCase();
            // not this window, not one already covered
            if (key === "" || seen[key] || key.includes("quickshell") || key.includes("noctalia-qs") || blocked.some(entry => key.includes(entry)))
                continue;
            seen[key] = true;
            list.push({
                "label": page.appName(cls),
                "value": key,
                "description": cls
            });
        }
        return list.sort((a, b) => a.label.localeCompare(b.label));
    }

    function appName(cls) {
        return DesktopEntries.heuristicLookup(cls)?.name || cls;
    }

    function setBlocked(list) {
        Config.autocomplete.excludeApps = list.join(", ");
    }

    function block(entry) {
        const key = String(entry).trim().toLowerCase();
        if (key !== "" && blocked.indexOf(key) < 0)
            setBlocked(blocked.concat([key]));
    }

    function unblock(entry) {
        setBlocked(blocked.filter(e => e !== entry));
    }

    function statusTitle() {
        switch (Autocomplete.status) {
        case "off":
            return "Off";
        case "building":
            return "Getting ready…";
        case "starting":
            return "Starting…";
        case "ready":
            return "Running";
        default:
            return "Not running";
        }
    }

    function statusDetails() {
        switch (Autocomplete.status) {
        case "off":
            return "Turn it on to get word suggestions while you type, in any app";
        case "building":
            return "Building the small helper program (only the first time)";
        case "starting":
            return "Registering as the input method";
        case "ready":
            return Autocomplete.fieldActive ? "A text field has the focus" : "Waiting for you to type in a text field";
        default:
            return Autocomplete.problem;
        }
    }

    function languageDetails(lang) {
        switch (Autocomplete.languageState(lang)) {
        case "ready":
            return Autocomplete.wordCount(lang).toLocaleString(Qt.locale("en_US"), "f", 0) + " words";
        case "downloading":
            return "Downloading the word list…";
        case "loading":
            return "Loading…";
        case "failed":
            return "Couldn't download the word list. Check the connection and try again.";
        default:
            return on ? "Downloaded the first time you type in this language" : "Not downloaded";
        }
    }

    title: "Autocomplete"
    subtitle: "Word suggestions while you type, in every app"

    headerActions: [
        ToggleSwitch {
            checked: page.on
            onToggled: enabled => Config.autocomplete.enabled = enabled
        }
    ]

    SettingGroup {
        SettingRow {
            icon: Autocomplete.status === "ready" ? "check_circle" : (page.broken ? "error" : "spellcheck")
            title: page.statusTitle()
            description: page.statusDetails()

            PillButton {
                visible: page.broken
                text: "Try again"
                onClicked: Autocomplete.start()
            }
        }
    }

    SettingGroup {
        title: "Suggestions"

        SettingRow {
            icon: "keyboard"
            title: "Start after"
            description: "Letters typed before suggestions show"

            Segmented {
                model: [1, 2, 3, 4].map(n => ({
                    "label": n + (n === 1 ? " letter" : " letters"),
                    "value": n
                }))
                value: Config.autocomplete.minChars
                onSelected: n => Config.autocomplete.minChars = n
            }
        }

        SettingRow {
            icon: "format_list_numbered"
            title: "How many"
            description: "Words offered at a time"

            Segmented {
                model: [3, 5, 7, 9]
                value: Config.autocomplete.maxSuggestions
                onSelected: n => Config.autocomplete.maxSuggestions = n
            }
        }

        SettingRow {
            icon: "pin_drop"
            title: "Where they appear"
            description: Config.autocomplete.position === "window" ? "In the bottom corner of the window you are typing in" : (Config.autocomplete.position === "caret" ? "Next to the text cursor, where you are typing" : "Under the mouse pointer")

            Segmented {
                model: [
                    {
                        "label": "Pointer",
                        "value": "pointer"
                    },
                    {
                        "label": "Text cursor",
                        "value": "caret"
                    },
                    {
                        "label": "Window",
                        "value": "window"
                    }
                ]
                value: Config.autocomplete.position
                onSelected: where => Config.autocomplete.position = where
            }
        }

        SettingRow {
            icon: "space_bar"
            title: "Space after a word"
            description: "Add a space when a suggestion is put in"

            ToggleSwitch {
                checked: Config.autocomplete.addSpace
                onToggled: enabled => Config.autocomplete.addSpace = enabled
            }
        }

        SettingRow {
            icon: "psychology"
            title: "Learn from what you pick"
            description: page.learnedCount > 0 ? page.learnedCount + (page.learnedCount === 1 ? " word" : " words") + " you completed come first. Kept on this computer only." : "Words you complete often come first. Kept on this computer only."

            PillButton {
                visible: page.learnedCount > 0
                text: "Forget"
                onClicked: Autocomplete.forgetLearned()
            }

            ToggleSwitch {
                checked: Config.autocomplete.learn
                onToggled: enabled => Config.autocomplete.learn = enabled
            }
        }
    }

    SettingGroup {
        title: "Languages"

        Repeater {
            model: Autocomplete.wantedLanguages

            delegate: SettingRow {
                id: language

                required property string modelData
                readonly property string state: Autocomplete.languageState(modelData)

                icon: "language"
                title: Autocomplete.languageName(modelData) + (modelData === Autocomplete.currentLanguage ? "  ·  layout in use" : "")
                description: page.languageDetails(modelData)

                PillButton {
                    visible: language.state === "missing" || language.state === "failed"
                    text: language.state === "failed" ? "Try again" : "Download"
                    onClicked: Autocomplete.ensureLanguage(language.modelData, language.state === "failed")
                }

                IconButton {
                    visible: language.state === "ready"
                    size: 32
                    iconSize: 18
                    icon: "refresh"
                    onClicked: Autocomplete.ensureLanguage(language.modelData, true)
                }

                IconButton {
                    visible: language.state === "ready"
                    size: 32
                    iconSize: 18
                    icon: "delete"
                    onClicked: Autocomplete.removeLanguage(language.modelData)
                }
            }
        }

        SettingRow {
            visible: Autocomplete.wantedLanguages.length === 0
            icon: "language"
            title: "No languages"
            description: "The word lists follow your keyboard layouts (Settings → Keyboard)"
        }

        SettingRow {
            visible: page.unsupportedLayouts.length > 0
            icon: "info"
            title: "No word list"
            description: "There are no suggestions for " + page.unsupportedLayouts.join(", ")
        }
    }

    SettingGroup {
        title: "Keys"

        SettingRow {
            icon: "keyboard_tab"
            title: "Tab"
            description: "Put the next suggestion into the text; press again for the one after. Shift + Tab goes back."
        }

        SettingRow {
            icon: "close"
            title: "Escape"
            description: "Close the suggestions and put back what you typed"
        }

        SettingRow {
            icon: "keyboard_return"
            title: "Any other key"
            description: "Keep typing: the word stays as it is. A click on a suggestion picks it too."
        }
    }

    SettingGroup {
        title: "Blocked apps"

        actions: [
            Dropdown {
                model: page.blockable
                caption: "Block an open app"
                icon: "block"
                searchable: page.blockable.length > 6
                popupWidth: 320
                onSelected: cls => page.block(cls)
            }
        ]

        SettingCard {
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.mutedColor
                font.pixelSize: 12
                text: "No suggestions in these apps, and their keys are not touched. Terminals are blocked from the start, because Tab completes commands there. Click one to allow it again."
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: page.blocked

                    delegate: Rectangle {
                        id: chip

                        required property string modelData

                        width: chipRow.implicitWidth + 22
                        height: 32
                        radius: 16
                        color: chipArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor
                        border.width: 1
                        border.color: Appearance.hairlineColor

                        RowLayout {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: 6

                            StyledText {
                                text: chip.modelData
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            MaterialSymbol {
                                icon: "close"
                                font.pixelSize: 15
                                color: Appearance.mutedColor
                            }
                        }

                        MouseArea {
                            id: chipArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.unblock(chip.modelData)
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animFast
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: page.blocked.length === 0
                text: "No apps are blocked"
                color: Appearance.mutedColor
                font.pixelSize: 13
            }
        }

        SettingRow {
            icon: "add"
            title: "Block by name"
            description: "Part of an app's window class, for an app that is not open right now"

            FieldInput {
                id: blockField

                implicitWidth: 200
                placeholder: "e.g. code"
                onAccepted: {
                    page.block(blockField.text);
                    blockField.clear();
                }
            }

            PillButton {
                enabled: blockField.text.trim() !== ""
                text: "Block"
                onClicked: {
                    page.block(blockField.text);
                    blockField.clear();
                }
            }
        }
    }

    SettingGroup {
        title: "Where it works"

        SettingCard {
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                lineHeight: 1.25
                color: Appearance.mutedColor
                font.pixelSize: 13
                text: "In every app that talks to input methods: GTK and Qt apps, Firefox, and Chromium-based browsers and apps. Apps running through XWayland do not.\n\nPassword fields are never read. What you type stays on this computer; only the word lists are downloaded."
            }
        }
    }
}
