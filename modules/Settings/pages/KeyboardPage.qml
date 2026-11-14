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

    function switchLabel(option) {
        const found = Keyboard.switchOptions.find(o => o.value === option);
        return found ? found.label : option;
    }

    title: "Keyboard"
    subtitle: Keyboard.fullLayoutName !== "" ? Keyboard.fullLayoutName + "  ·  " + Keyboard.layouts.length + (Keyboard.layouts.length === 1 ? " layout" : " layouts") : ""
    Component.onCompleted: {
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
