import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

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

    title: "Launcher"
    subtitle: "Apps, files and web search from one box"

    SettingGroup {
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
}
