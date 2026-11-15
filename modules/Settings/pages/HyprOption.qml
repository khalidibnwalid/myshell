import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// One Hyprland option as a settings row: the control that fits its type, and a
// button to hand it back to the hand-written config once it has been changed here.
SettingRow {
    id: row

    required property var option
    // asks the page to open its colour picker for this option
    signal pickColor(string name)

    enabled: HyprSettings.enabled
    opacity: enabled ? 1 : 0.6

    readonly property string name: option.name
    readonly property var value: HyprSettings.valueOf(name)
    readonly property bool changed: HyprSettings.isChanged(name)
    readonly property bool managed: HyprSettings.isManaged(name)
    readonly property bool ranged: option.min !== null && option.max !== null
    // the choices of a pick-from-a-list option, plus the current value when it is not among them
    // built when a dropdown is created, not for every row
    function selectChoices() {
        const now = shown(value);
        const list = option.choices.slice();
        if (option.kind === "select" && !list.some(c => c.value === now) && now !== "")
            list.push({
                "label": now,
                "value": now
            });
        return list;
    }

    function fontChoices() {
        const list = HyprSettings.fonts();
        const now = shown(value);
        return now !== "" && list.indexOf(now) < 0 ? [now].concat(list) : list;
    }

    function monitorChoices() {
        return [
            {
                "label": "Automatic",
                "value": ""
            }
        ].concat(Hyprland.monitors.values.map(m => ({
                        "label": m.name,
                        "value": m.name
                    })));
    }

    readonly property real span: ranged ? option.max - option.min : 1

    // the row already shows the description, so the info popup is only worth opening
    // when it tells more: a range, or the choices with their values
    readonly property bool hasMore: ranged || option.choices.length > 0

    // lines of the info popup: [label, value]
    readonly property var facts: {
        const list = [["Type", HyprSettings.typeLabel(option)]];
        const def = shown(option.def);
        list.push(["Default", def === "" ? "unset" : def]);
        if (ranged)
            list.push(["Range", option.min + " to " + option.max]);
        if (option.choices.length > 0)
            list.push(["Choices", option.choices.map(c => option.kind === "choice" ? c.label + " (" + c.value + ")" : c.label).join(", ")]);
        const now = shown(value);
        list.push(["Now", now === "" ? "unset" : now]);
        return list;
    }

    function numeric(v) {
        const n = Number(v);
        return isNaN(n) ? (typeof option.def === "number" ? option.def : 0) : n;
    }

    function shown(v) {
        if (v === "[[EMPTY]]" || v === undefined || v === null)
            return "";
        return Array.isArray(v) ? v.join(", ") : String(v);
    }

    property bool editing: false

    // a number typed in place of the slider's: kept inside the range
    function commitNumber(text) {
        editing = false;
        const n = Number(text.trim().replace(",", "."));
        if (text.trim() === "" || isNaN(n))
            return;
        const clamped = Math.max(option.min, Math.min(option.max, n));
        HyprSettings.set(name, option.kind === "int" ? Math.round(clamped) : Math.round(clamped * 100) / 100);
    }

    function commitText(text) {
        const t = text.trim();
        if (option.kind === "int" || option.kind === "float") {
            const n = Number(t);
            if (t === "" || isNaN(n))
                return;
            HyprSettings.set(name, option.kind === "int" ? Math.round(n) : n);
        } else if (option.kind === "list") {
            const parts = t.split(/[ ,]+/).filter(x => x !== "").map(Number);
            if (parts.length > 0 && !parts.some(isNaN))
                HyprSettings.set(name, parts);
        } else {
            HyprSettings.set(name, t);
        }
    }

    icon: HyprSettings.iconFor(option)
    title: option.title
    description: (option.group !== "" ? option.group.charAt(0).toUpperCase() + option.group.slice(1) + " · " : "") + option.description

    IconButton {
        id: infoButton

        visible: row.hasMore
        icon: "info"
        size: 30
        iconSize: 18
        color: Appearance.mutedColor
        toggled: infoLoader.item ? infoLoader.item.opened : false
        onClicked: {
            if (!infoLoader.active)
                infoLoader.active = true;
            else if (infoLoader.item.opened)
                infoLoader.item.close();
            else
                infoLoader.item.open();
        }
    }

    // the popup is built the first time the icon is clicked, not for every row
    Loader {
        id: infoLoader

        active: false
        sourceComponent: infoPopupComponent
        onLoaded: item.open()
    }

    IconButton {
        visible: row.changed && !row.managed
        icon: "restart_alt"
        size: 30
        iconSize: 18
        color: Appearance.mutedColor
        onClicked: HyprSettings.reset(row.name)
    }

    MaterialSymbol {
        visible: row.managed
        icon: "palette"
        font.pixelSize: 18
        color: Appearance.accentColor
    }

    StyledText {
        visible: row.managed
        text: "Follows the accent"
        color: Appearance.mutedColor
        font.pixelSize: 12
    }


    Component {
        id: toggleControl

        ToggleSwitch {
            checked: row.value === true || row.value === 1
            onToggled: enabled => HyprSettings.set(row.name, enabled)
        }
    }

    Component {
        id: choiceControl

        Dropdown {
            implicitWidth: 190
            model: row.option.choices
            value: Number(row.value)
            onSelected: v => HyprSettings.set(row.name, v)
        }
    }

    Component {
        id: sliderControl

        RowLayout {
            spacing: 10

            // the number: click it to type an exact value
            Item {
                id: numberBox

                Layout.preferredWidth: 60
                Layout.preferredHeight: 28

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    visible: !row.editing && numberArea.containsMouse
                    color: Appearance.surfaceHighColor
                }

                StyledText {
                    anchors.fill: parent
                    visible: !row.editing
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: row.option.kind === "int" ? String(Math.round(row.numeric(row.value))) : row.numeric(row.value).toFixed(2)
                    color: numberArea.containsMouse ? Appearance.fgColor : Appearance.mutedColor
                    font.pixelSize: 12
                }

                MouseArea {
                    id: numberArea

                    anchors.fill: parent
                    visible: !row.editing
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    onClicked: {
                        row.editing = true;
                        numberInput.text = row.option.kind === "int" ? String(Math.round(row.numeric(row.value))) : String(row.numeric(row.value));
                        numberInput.forceActiveFocus();
                        numberInput.selectAll();
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: row.editing
                    radius: 14
                    color: Appearance.surfaceHighColor
                    border.width: 1
                    border.color: Appearance.accentColor

                    TextInput {
                        id: numberInput

                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        color: Appearance.fgColor
                        selectionColor: Appearance.accentColor
                        selectedTextColor: Appearance.accentContrastColor
                        font.family: Appearance.fontFamily
                        font.pixelSize: 12
                        selectByMouse: true
                        inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhSensitiveData
                        Keys.onEscapePressed: row.editing = false
                        onAccepted: row.commitNumber(text)
                        onActiveFocusChanged: {
                            if (!activeFocus && row.editing)
                                row.commitNumber(text);
                        }
                    }
                }
            }

            PillSlider {
                implicitWidth: 190
                implicitHeight: 30
                icon: ""
                value: Math.max(0, Math.min(1, (row.numeric(row.value) - row.option.min) / row.span))
                onDragged: v => {
                    const n = row.option.min + v * row.span;
                    HyprSettings.set(row.name, row.option.kind === "int" ? Math.round(n) : Math.round(n * 100) / 100);
                }
            }
        }
    }

    Component {
        id: colorControl

        RowLayout {
            spacing: 6

            ColorWell {
                enabled: !row.managed
                color: HyprSettings.toColor(row.value)
                onClicked: row.pickColor(row.name)
            }

            FieldInput {
                implicitWidth: 120
                placeholder: "#rrggbbaa"
                value: {
                    const c = HyprSettings.toColor(row.value);
                    return "#" + HyprSettings.pad(c.r) + HyprSettings.pad(c.g) + HyprSettings.pad(c.b) + HyprSettings.pad(c.a);
                }
                onCommitted: text => {
                    const m = text.trim().match(/^#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/);
                    if (m)
                        HyprSettings.set(row.name, "rgba(" + m[1] + (m[2] || "ff") + ")");
                    else
                        reset();
                }
            }
        }
    }

    Component {
        id: selectControl

        Dropdown {
            implicitWidth: 190
            model: row.selectChoices()
            value: row.shown(row.value)
            onSelected: v => HyprSettings.set(row.name, v)
        }
    }

    Component {
        id: fontControl

        Dropdown {
            implicitWidth: 220
            popupWidth: 300
            searchable: true
            model: row.fontChoices()
            value: row.shown(row.value)
            onSelected: v => HyprSettings.set(row.name, v)
        }
    }

    Component {
        id: monitorControl

        Dropdown {
            implicitWidth: 190
            model: row.monitorChoices()
            value: row.shown(row.value) === "Auto" ? "" : row.shown(row.value)
            onSelected: v => HyprSettings.set(row.name, v)
        }
    }

    Component {
        id: textControl

        FieldInput {
            implicitWidth: row.option.kind === "text" ? 220 : 130
            value: row.shown(row.value)
            onCommitted: text => row.commitText(text)
        }
    }

    // only the control this option needs is built
    Loader {
        Layout.alignment: Qt.AlignVCenter
        sourceComponent: {
            switch (row.option.kind) {
            case "bool":
                return toggleControl;
            case "choice":
                return choiceControl;
            case "int":
            case "float":
                return row.ranged ? sliderControl : textControl;
            case "color":
                return colorControl;
            case "select":
                return selectControl;
            case "font":
                return fontControl;
            case "monitor":
                return monitorControl;
            default:
                return textControl;
            }
        }
    }

    Component {
        id: infoPopupComponent

        Popup {
            id: infoPopup

            // opens upwards when there is no room below the row
            property bool above: false

            parent: infoButton
            x: infoButton.width - width
            y: above ? -height - 6 : infoButton.height + 6
            onAboutToShow: above = infoButton.mapToItem(null, 0, 0).y + infoButton.height + 6 + implicitHeight > Overlay.overlay.height
            width: 380
            padding: 18
            modal: false
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
            enter: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Appearance.animFast
                }
            }

            background: Rectangle {
                radius: 20
                color: Appearance.bgColor
                border.width: 1
                border.color: Appearance.outlineColor
            }

            contentItem: ColumnLayout {
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialSymbol {
                        icon: row.icon
                        font.pixelSize: 22
                        color: Appearance.accentColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: row.option.title
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: row.name
                            elide: Text.ElideRight
                            color: Appearance.mutedColor
                            font.pixelSize: 12
                            font.family: "monospace"
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: row.option.description !== "" ? row.option.description : "No description."
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.hairlineColor
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 14
                    rowSpacing: 6

                    Repeater {
                        model: row.facts

                        delegate: Item {
                            id: fact

                            required property var modelData
                            required property int index

                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            implicitHeight: factRow.implicitHeight

                            RowLayout {
                                id: factRow

                                width: parent.width
                                spacing: 14

                                StyledText {
                                    Layout.preferredWidth: 64
                                    Layout.alignment: Qt.AlignTop
                                    text: fact.modelData[0]
                                    color: Appearance.mutedColor
                                    font.pixelSize: 12
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: fact.modelData[1]
                                    wrapMode: Text.Wrap
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    PillButton {
                        icon: "open_in_new"
                        text: "Open in the wiki"
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", HyprSettings.docsUrl(row.option)]);
                            infoPopup.close();
                        }
                    }

                    PillButton {
                        icon: "content_copy"
                        text: "Copy name"
                        onClicked: {
                            Quickshell.execDetached(["wl-copy", row.name]);
                            infoPopup.close();
                        }
                    }
                }
            }
        }
    }
}
