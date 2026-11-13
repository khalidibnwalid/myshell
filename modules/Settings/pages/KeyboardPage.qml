import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page

    readonly property var labels: Config.keyboard?.layouts ?? ({})
    readonly property var names: Object.keys(labels)

    function setLabel(name, label) {
        const next = Object.assign({}, labels);
        if (label === null)
            delete next[name];
        else
            next[name] = label;
        Config.setIn("keyboard", "layouts", next);
    }

    function add() {
        const name = newName.text.trim();
        const label = newLabel.text.trim();
        if (name === "" || label === "")
            return;
        setLabel(name, label);
        newName.clear();
        newLabel.clear();
    }

    title: "Keyboard"
    subtitle: Keyboard.fullLayoutName

    SettingGroup {
        title: "Layout"

        SettingRow {
            icon: "language"
            title: Keyboard.fullLayoutName || "Unknown layout"
            description: "Shown as “" + Keyboard.layout + "” in the bar. Layouts themselves are set in the Hyprland config (input:kb_layout)."

            PillButton {
                icon: "swap_horiz"
                text: "Next layout"
                onClicked: Keyboard.nextLayout()
            }
        }
    }

    SettingGroup {
        title: "Bar labels"

        Repeater {
            model: page.names

            delegate: SettingRow {
                id: row

                required property string modelData

                title: modelData
                description: "Layouts whose name contains this text"

                FieldInput {
                    implicitWidth: 96
                    value: page.labels[row.modelData] ?? ""
                    onCommitted: text => {
                        if (text.trim() !== "")
                            page.setLabel(row.modelData, text.trim());
                    }
                }

                IconButton {
                    icon: "delete"
                    onClicked: page.setLabel(row.modelData, null)
                }
            }
        }

        SettingCard {
            StyledText {
                Layout.fillWidth: true
                text: "Add a label"
                font.weight: Font.Medium
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                FieldInput {
                    id: newName

                    Layout.fillWidth: true
                    placeholder: "Layout name, e.g. Turkish"
                    onAccepted: page.add()
                }

                FieldInput {
                    id: newLabel

                    implicitWidth: 120
                    placeholder: "Label, e.g. TR"
                    onAccepted: page.add()
                }

                PillButton {
                    toggled: true
                    enabled: newName.text.trim() !== "" && newLabel.text.trim() !== ""
                    icon: "add"
                    text: "Add"
                    onClicked: page.add()
                }
            }
        }
    }
}
