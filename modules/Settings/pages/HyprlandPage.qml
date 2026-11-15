import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

// Every Hyprland option. "Look" holds the ones most people change (borders, gaps,
// blur, shadow…); the other tabs list everything Hyprland offers, taken from the
// installed version, and the search looks through all of it.
SettingsPage {
    id: page

    property string category: "look"
    property string query: ""
    property string pickTarget: ""

    readonly property var currentCategory: HyprSettings.categories.find(c => c.id === category) || HyprSettings.categories[0]
    readonly property bool searching: query.trim() !== ""
    readonly property int categoryCount: currentCategory.sections ? HyprSettings.inCategory(currentCategory).length : 0
    readonly property var found: HyprSettings.search(query)
    // the options of the tab, in groups: [{ title, items }]
    readonly property var groups: {
        if (searching)
            return [
                {
                    "title": found.length === 0 ? "" : found.length + (found.length === 1 ? " result" : " results"),
                    "items": found
                }
            ];
        if (currentCategory.curated) {
            return HyprSettings.curated.map(g => ({
                        "title": g.title,
                        "items": g.names.map(n => HyprSettings.optionMap[n]).filter(o => o !== undefined)
                    }));
        }
        const list = HyprSettings.inCategory(currentCategory);
        const byGroup = {};
        const order = [];
        for (const o of list) {
            const key = currentCategory.sections.length > 1 ? o.section + (o.group !== "" ? " " + o.group : "") : o.group;
            if (!(key in byGroup)) {
                byGroup[key] = [];
                order.push(key);
            }
            byGroup[key].push(o);
        }
        return order.map(key => ({
                    "title": key === "" ? currentCategory.label : HyprSettings.humanize(key),
                    "items": byGroup[key]
                }));
    }

    // scroll the tab bar so the open tab shows
    onCategoryChanged: Qt.callLater(() => {
        const index = HyprSettings.categories.findIndex(c => c.id === category);
        const x = index * 42;
        if (x < tabFlick.contentX || x + 42 > tabFlick.contentX + tabFlick.width)
            tabFlick.contentX = Math.max(0, Math.min(tabFlick.contentWidth - tabFlick.width, x - 80));
    })

    function pickColor(name) {
        pickTarget = name;
        const c = HyprSettings.toColor(HyprSettings.valueOf(name));
        colorPicker.openWith(Qt.rgba(c.r, c.g, c.b, 1), HyprSettings.optionMap[name].title);
    }

    // the picker has no transparency: the colour keeps the one it had
    function applyColor(c) {
        const old = HyprSettings.toColor(HyprSettings.valueOf(pickTarget));
        HyprSettings.set(pickTarget, HyprSettings.fromColor(Qt.rgba(c.r, c.g, c.b, old.a)));
    }

    leading: [
        HyprlandLogo {
            size: 40
            color: Appearance.accentColor
        }
    ]

    title: "Hyprland"
    subtitle: HyprSettings.problem !== "" ? HyprSettings.problem : "Every window manager option" + (HyprSettings.version !== "" ? " · " + HyprSettings.version : "") + " · " + (HyprSettings.format === "lua" ? "Lua config" : "hyprlang config")

    headerActions: [
        PillButton {
            visible: HyprSettings.enabled && HyprSettings.changedCount > 0
            icon: "restart_alt"
            text: "Reset " + HyprSettings.changedCount + (HyprSettings.changedCount === 1 ? " change" : " changes")
            onClicked: HyprSettings.resetAll()
        },
        ToggleSwitch {
            checked: HyprSettings.enabled
            onToggled: enabled => HyprSettings.setEnabled(enabled)
        }
    ]

    ColorPicker {
        id: colorPicker

        swatches: [Appearance.accentColor]
        recents: Config.recentColors || []
        onPreviewed: c => page.applyColor(c)
        onApplied: c => page.applyColor(c)
        onCancelled: page.applyColor(colorPicker.original)
    }

    SettingGroup {
        visible: !HyprSettings.enabled

        SettingRow {
            icon: "lock"
            title: "Read only"
            description: "Hyprland is left to your own config in ~/.config/hypr. The values below are what it uses now, and nothing here is written or applied. The changes you made are kept; turn the switch on to use them and edit again."
        }
    }

    FieldInput {
        Layout.fillWidth: true
        icon: "search"
        placeholder: "Search all " + HyprSettings.options.length + " options"
        onEdited: text => page.query = text
        onCommitted: text => page.query = text
    }

    // the tabs: icons, and the name of the one that is open (or hovered)
    Rectangle {
        id: tabBar

        Layout.fillWidth: true
        visible: !page.searching
        implicitHeight: 52
        radius: 26
        color: Appearance.surfaceColor

        Flickable {
            id: tabFlick

            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            contentWidth: tabRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Row {
                id: tabRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: HyprSettings.categories

                    delegate: Rectangle {
                        id: tab

                        required property var modelData
                        readonly property bool current: page.category === modelData.id
                        readonly property bool open: current || tabArea.containsMouse

                        height: 40
                        width: 20 + 20 + (open ? tabLabel.implicitWidth + 8 : 0)
                        radius: 20
                        clip: true
                        color: current ? Appearance.accentColor : (tabArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            spacing: 8

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: tab.modelData.icon
                                fill: tab.current ? 1 : 0
                                font.pixelSize: 20
                                color: tab.current ? Appearance.accentContrastColor : Appearance.fgColor
                            }

                            StyledText {
                                id: tabLabel

                                anchors.verticalCenter: parent.verticalCenter
                                visible: tab.open
                                text: tab.modelData.label
                                font.weight: Font.Medium
                                color: tab.current ? Appearance.accentContrastColor : Appearance.fgColor
                            }
                        }

                        MouseArea {
                            id: tabArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.category = tab.modelData.id
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Appearance.animFast
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animFast
                            }
                        }
                    }
                }
            }
        }

        // the wheel moves the tabs sideways
        WheelHandler {
            onWheel: event => {
                const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                tabFlick.contentX = Math.max(0, Math.min(tabFlick.contentWidth - tabFlick.width, tabFlick.contentX - d));
            }
        }
    }

    // what the open tab is about
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        visible: !page.searching
        spacing: 14

        Rectangle {
            implicitWidth: 44
            implicitHeight: 44
            radius: 22
            color: Qt.alpha(Appearance.accentColor, 0.2)

            MaterialSymbol {
                anchors.centerIn: parent
                icon: page.currentCategory.icon
                fill: 1
                font.pixelSize: 24
                color: Appearance.accentColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                text: page.currentCategory.label
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            StyledText {
                Layout.fillWidth: true
                text: (page.currentCategory.description || "") + (page.currentCategory.curated ? "" : "  ·  " + page.categoryCount + " options")
                wrapMode: Text.Wrap
                color: Appearance.mutedColor
                font.pixelSize: 12
            }
        }
    }

    // the accent colour for the borders
    SettingGroup {
        visible: !page.searching && page.category === "look"
        title: "Colours"

        SettingRow {
            icon: "palette"
            title: "Borders follow the accent colour"
            description: "The active window border and the border of grouped windows use the shell's accent colour and change with it. Turn it off to pick them yourself below."

            ColorWell {
                color: Appearance.accentColor
                enabled: false
            }

            ToggleSwitch {
                enabled: HyprSettings.enabled
                checked: Config.hyprland?.accentBorder ?? true
                onToggled: enabled => HyprSettings.setAccentBorder(enabled)
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: HyprSettings.options.length === 0 || (page.searching && page.found.length === 0)
        horizontalAlignment: Text.AlignHCenter
        topPadding: 20
        text: HyprSettings.options.length === 0 ? (HyprSettings.problem !== "" ? HyprSettings.problem : "Reading the options from Hyprland…") : "No option matches \"" + page.query.trim() + "\""
        color: Appearance.mutedColor
    }

    Repeater {
        model: page.groups

        delegate: SettingGroup {
            id: group

            required property var modelData

            title: modelData.title

            Repeater {
                model: group.modelData.items

                delegate: HyprOption {
                    required property var modelData

                    option: modelData
                    onPickColor: name => page.pickColor(name)
                }
            }
        }
    }

    SettingGroup {
        visible: !page.searching
        title: "About"

        SettingRow {
            icon: "info"
            title: "Where these are saved"
            description: "Changes apply at once and are written to ~/.config/hypr/config/quickshell.conf (and quickshell.lua for the new Lua format), which your Hyprland config includes last, so they win over your own files for the options you changed. Your own files are never edited. The reset buttons hand one value back to them, and the switch at the top hands back everything."
        }
    }
}
