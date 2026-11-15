import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page

    // the list being edited; it only reaches the system with Apply
    property var draftCodes: []
    property var draftVariants: []
    property string draftSwitch: ""
    readonly property bool dirty: JSON.stringify([draftCodes, draftVariants, draftSwitch]) !== JSON.stringify([Keyboard.codes, Keyboard.variantList, Keyboard.switchOption])
    readonly property var addable: Keyboard.available.filter(a => draftCodes.indexOf(a.code) < 0).map(a => ({
        "label": a.name,
        "value": a.code,
        "description": a.code
    }))

    function sync() {
        draftCodes = Keyboard.codes.slice();
        draftVariants = Keyboard.variantList.slice();
        draftSwitch = Keyboard.switchOption;
    }

    function addLayout(code) {
        draftCodes = draftCodes.concat([code]);
        draftVariants = draftVariants.concat([""]);
    }

    function removeLayout(index) {
        if (draftCodes.length <= 1)
            return;
        draftCodes = draftCodes.filter((c, i) => i !== index);
        draftVariants = draftVariants.filter((v, i) => i !== index);
    }

    function moveLayout(index, delta) {
        const to = index + delta;
        if (to < 0 || to >= draftCodes.length)
            return;
        const codes = draftCodes.slice();
        const variants = draftVariants.slice();
        [codes[index], codes[to]] = [codes[to], codes[index]];
        [variants[index], variants[to]] = [variants[to], variants[index]];
        draftCodes = codes;
        draftVariants = variants;
    }

    function setVariant(index, variant) {
        const variants = draftVariants.slice();
        variants[index] = variant;
        draftVariants = variants;
    }

    function layoutName(code) {
        return Keyboard.names[code] || code.toUpperCase();
    }

    function variantLabel(code, variant) {
        const found = (Keyboard.variantMap[code] || []).find(v => v.name === variant);
        return found ? found.label : "";
    }

    // the words for the levels of the backlight: Off, Low, High (or Low, Medium, High)
    function lightLevels() {
        const max = KeyboardLight.maxLevel;
        const names = max === 1 ? ["Off", "On"] : (max === 2 ? ["Off", "Low", "High"] : ["Off", "Low", "Medium", "High"]);
        const list = names.map((label, value) => ({
                    "label": label,
                    "value": value
                }));
        // follows the ambient light sensor, when there is one
        if (KeyboardLight.luxAvailable)
            list.push({
                "label": "Auto (shell)",
                "value": -1
            });
        return list;
    }

    function idleLabel(seconds) {
        return seconds >= 60 ? (seconds / 60) + (seconds === 60 ? " minute" : " minutes") : seconds + " seconds";
    }

    function switchLabel(option) {
        const found = Keyboard.switchOptions.find(o => o.value === option);
        return found ? found.label : option;
    }

    title: "Keyboard"
    subtitle: Keyboard.fullLayoutName !== "" ? Keyboard.fullLayoutName + "  ·  " + Keyboard.layouts.length + (Keyboard.layouts.length === 1 ? " layout" : " layouts") : ""
    Component.onCompleted: {
        KeyboardLight.refresh();
        Keyboard.refresh();
        sync();
    }

    // the system changed (after Apply, or from outside)
    Connections {
        function onCodesChanged() {
            page.sync();
        }

        function onVariantListChanged() {
            page.sync();
        }

        function onOptionsChanged() {
            page.sync();
        }

        target: Keyboard
    }

    // --- changes waiting to be applied ---
    SettingGroup {
        visible: page.dirty

        SettingRow {
            icon: "pending"
            title: "Unapplied changes"
            description: "Apply puts these layouts to work now and keeps them for the next start (" + Keyboard.hyprDir + "/config/keyboard.conf)"

            PillButton {
                text: "Reset"
                onClicked: page.sync()
            }

            PillButton {
                toggled: true
                icon: "check"
                text: "Apply"
                onClicked: Keyboard.apply(page.draftCodes, page.draftVariants, page.draftSwitch)
            }
        }
    }

    // --- layouts ---
    SettingGroup {
        title: "Layouts"

        actions: [
            Dropdown {
                model: page.addable
                caption: "Add layout"
                icon: "add"
                searchable: true
                popupWidth: 300
                onSelected: code => page.addLayout(code)
            }
        ]

        Repeater {
            model: page.draftCodes

            delegate: SettingRow {
                id: row

                required property string modelData
                required property int index
                readonly property bool active: !page.dirty && Keyboard.activeIndex === index
                readonly property string name: page.layoutName(modelData)
                readonly property string variant: page.draftVariants[index] || ""
                readonly property var variantChoices: Keyboard.variantMap[modelData] || []

                icon: "keyboard"
                title: name + (active ? "  ·  in use" : "")
                description: modelData + (variant !== "" ? "  ·  " + page.variantLabel(modelData, variant) : "") + (index === 0 ? "  ·  first" : "")

                Dropdown {
                    visible: row.variantChoices.length > 0
                    model: [
                        {
                            "label": "Default",
                            "value": ""
                        }
                    ].concat(row.variantChoices.map(v => ({
                        "label": v.label,
                        "value": v.name
                    })))
                    value: row.variant
                    placeholder: "Default"
                    searchable: row.variantChoices.length > 6
                    popupWidth: 300
                    onSelected: v => page.setVariant(row.index, v)
                }

                PillButton {
                    visible: !page.dirty && !row.active
                    text: "Use"
                    onClicked: Keyboard.setLayout(row.index)
                }

                IconButton {
                    enabled: row.index > 0
                    opacity: enabled ? 1 : 0.3
                    size: 32
                    iconSize: 18
                    icon: "arrow_upward"
                    onClicked: page.moveLayout(row.index, -1)
                }

                IconButton {
                    enabled: row.index < page.draftCodes.length - 1
                    opacity: enabled ? 1 : 0.3
                    size: 32
                    iconSize: 18
                    icon: "arrow_downward"
                    onClicked: page.moveLayout(row.index, 1)
                }

                IconButton {
                    enabled: page.draftCodes.length > 1
                    opacity: enabled ? 1 : 0.3
                    size: 32
                    iconSize: 18
                    icon: "delete"
                    onClicked: page.removeLayout(row.index)
                }
            }
        }
    }

    // --- switching ---
    SettingGroup {
        title: "Switching"

        SettingRow {
            icon: "swap_horiz"
            title: "Shortcut"
            description: page.draftSwitch === "" ? "No shortcut: switch from the bar, or with a Hyprland key bind" : "Press " + page.switchLabel(page.draftSwitch) + " to go to the next layout"

            Dropdown {
                model: [
                    {
                        "label": "None",
                        "value": ""
                    }
                ].concat(Keyboard.switchOptions)
                value: page.draftSwitch
                placeholder: page.draftSwitch !== "" ? page.switchLabel(page.draftSwitch) : "None"
                searchable: true
                popupWidth: 340
                onSelected: option => page.draftSwitch = option
            }
        }

        SettingRow {
            visible: Keyboard.layouts.length > 1
            icon: "language"
            title: "Next layout"
            description: "Switch now, the same as the shortcut"

            PillButton {
                text: "Switch"
                onClicked: Keyboard.nextLayout()
            }
        }
    }

    // --- the light under the keys, on laptops that have one ---
    SettingGroup {
        visible: KeyboardLight.available
        title: "Backlight"

        SettingRow {
            icon: "keyboard"
            title: "Brightness"
            description: KeyboardLight.auto ? "Auto (shell), follows the room" + (KeyboardLight.lux >= 0 ? " · the room is at " + Math.round(KeyboardLight.lux) + " lux" : "") : (KeyboardLight.untouched ? "Left to the laptop: its own auto mode, or off. Pick a level to take over." : (KeyboardLight.level === 0 ? "Off" : "Level " + KeyboardLight.level + " of " + KeyboardLight.maxLevel) + "  ·  Fn+Space hands it back to the laptop's auto mode")

            Segmented {
                visible: KeyboardLight.maxLevel <= 3
                model: page.lightLevels()
                value: KeyboardLight.auto ? -1 : (KeyboardLight.untouched ? -2 : KeyboardLight.level)
                onSelected: v => v < 0 ? KeyboardLight.setAuto(true) : KeyboardLight.setManual(v)
            }

            PillSlider {
                visible: KeyboardLight.maxLevel > 3
                implicitWidth: 220
                implicitHeight: 32
                icon: "keyboard"
                value: KeyboardLight.maxLevel > 0 ? KeyboardLight.level / KeyboardLight.maxLevel : 0
                onDragged: v => KeyboardLight.setManual(v * KeyboardLight.maxLevel)
            }
        }

        SettingRow {
            visible: KeyboardLight.auto
            icon: "light_mode"
            title: "Switch on in rooms darker than"
            description: "Read from the ambient light sensor next to the camera. Brighter again turns it off, with some margin so it doesn't flicker."

            Dropdown {
                implicitWidth: 170
                model: [
                    {
                        "label": "A dark room",
                        "value": 5
                    },
                    {
                        "label": "Dim (default)",
                        "value": 20
                    },
                    {
                        "label": "Normal indoors",
                        "value": 60
                    },
                    {
                        "label": "Fairly bright",
                        "value": 150
                    }
                ]
                value: KeyboardLight.autoLux
                onSelected: v => KeyboardLight.setAutoLux(v)
            }
        }

        SettingRow {
            icon: "bedtime"
            title: "Turn off when idle"
            description: KeyboardLight.idleSeconds > 0 ? "Off after " + page.idleLabel(KeyboardLight.idleSeconds) + " without typing, on again at the next key" : "Keep it on at all times"

            Dropdown {
                visible: KeyboardLight.idleSeconds > 0
                implicitWidth: 120
                model: [
                    {
                        "label": "10 seconds",
                        "value": 10
                    },
                    {
                        "label": "30 seconds",
                        "value": 30
                    },
                    {
                        "label": "1 minute",
                        "value": 60
                    },
                    {
                        "label": "5 minutes",
                        "value": 300
                    }
                ]
                value: KeyboardLight.idleSeconds
                onSelected: v => KeyboardLight.setIdleSeconds(v)
            }

            ToggleSwitch {
                checked: KeyboardLight.idleSeconds > 0
                onToggled: on => KeyboardLight.setIdleSeconds(on ? 30 : 0)
            }
        }
    }

    // --- how each layout is named in the bar ---
    SettingGroup {
        title: "Bar labels"

        Repeater {
            model: Keyboard.layouts

            delegate: SettingRow {
                id: labelRow

                required property var modelData
                readonly property bool custom: Keyboard.customKey(modelData.name) !== ""

                title: modelData.name
                description: "Shown in the bar and on the lock screen" + (custom ? "" : "  ·  default")

                FieldInput {
                    implicitWidth: 96
                    value: labelRow.modelData.label
                    onCommitted: text => {
                        if (text.trim() !== "")
                            Keyboard.setLabel(labelRow.modelData.name, text.trim());
                    }
                }

                IconButton {
                    visible: labelRow.custom
                    size: 32
                    iconSize: 18
                    icon: "restart_alt"
                    onClicked: Keyboard.resetLabel(labelRow.modelData.name)
                }
            }
        }
    }
}
