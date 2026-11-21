import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

// The options of one widget: its look (the clock type, ...), colours, font, weight, shadow and
// see-through. Everything not set is the theme's default; "Reset" puts all of it back.
Rectangle {
    id: root

    required property string wid
    // the room it may take on the screen
    property real maxHeight: 800

    readonly property var cfg: DesktopWidgets.items.find(i => i.id === wid) ?? ({})
    readonly property var info: DesktopWidgets.typeInfo(cfg.type ?? "")
    readonly property bool hasStyles: (info?.styles?.length ?? 0) > 1
    // what is typed in the font search
    property string fontQuery: ""
    readonly property var fontChoices: {
        const q = fontQuery.trim().toLowerCase();
        if (q === "")
            return ["", ...DesktopWidgets.fonts];
        return DesktopWidgets.fonts.filter(f => f.toLowerCase().indexOf(q) >= 0);
    }
    readonly property var swatches: ["", ...DesktopWidgets.palette]

    function set(key, value) {
        const patch = {};
        patch[key] = value;
        DesktopWidgets.update(wid, patch);
    }

    // a letter typed anywhere on the desktop goes to the font search
    function typeInto(text) {
        fontSearch.append(text);
    }

    function isHex(text) {
        return /^#?([0-9a-f]{6}|[0-9a-f]{3})$/i.test(text.trim());
    }

    width: 380
    height: Math.min(maxHeight, flick.contentHeight + 32)
    radius: 36
    // opaque enough to read over any window: the layer is not blurred
    color: Qt.alpha(Appearance.bgColor, 0.95)
    border.width: 1
    border.color: Appearance.outlineColor

    // clicks on the panel are not clicks on the desktop behind it
    MouseArea {
        anchors.fill: parent
    }

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.margins: 16
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col

            width: flick.width
            spacing: 14

            // header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    icon: root.info?.icon ?? "widgets"
                    font.pixelSize: 24
                    color: Appearance.accentColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: (root.info?.label ?? "Widget") + " options"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                IconButton {
                    icon: "close"
                    iconSize: 20
                    size: 34
                    onClicked: DesktopWidgets.optionsFor = ""
                }
            }

            // the look, e.g. the type of clock
            ColumnLayout {
                visible: root.hasStyles
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: root.cfg.type === "clock" ? "Clock type" : "Look"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Segmented {
                    Layout.fillWidth: true
                    model: (root.info?.styles ?? []).map(s => ({
                                "label": DesktopWidgets.styleLabels[s] ?? s,
                                "value": s
                            }))
                    value: root.cfg.style ?? root.info?.styles?.[0]
                    onSelected: v => root.set("style", v)
                }
            }

            // the space in the time: between the digits, and between the words of the date
            Repeater {
                model: root.cfg.type === "clock" ? [
                    {
                        "key": "gap",
                        "title": "Space between hours and minutes",
                        "choices": [
                            {
                                "label": "Overlap",
                                "value": "overlap"
                            },
                            {
                                "label": "Tight",
                                "value": "tight"
                            },
                            {
                                "label": "Normal",
                                "value": null
                            },
                            {
                                "label": "Wide",
                                "value": "wide"
                            },
                            {
                                "label": "Wider",
                                "value": "wider"
                            }
                        ]
                    },
                    {
                        "key": "digitGap",
                        "title": "Space between the digits",
                        "choices": [
                            {
                                "label": "Tight",
                                "value": "tight"
                            },
                            {
                                "label": "Normal",
                                "value": null
                            },
                            {
                                "label": "Wide",
                                "value": "wide"
                            },
                            {
                                "label": "Wider",
                                "value": "wider"
                            }
                        ]
                    },
                    {
                        "key": "dateGap",
                        "title": "Space between the words of the date",
                        "choices": [
                            {
                                "label": "Tight",
                                "value": "tight"
                            },
                            {
                                "label": "Normal",
                                "value": null
                            },
                            {
                                "label": "Wide",
                                "value": "wide"
                            },
                            {
                                "label": "Wider",
                                "value": "wider"
                            }
                        ]
                    }
                ] : []

                ColumnLayout {
                    id: spaceRow

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: spaceRow.modelData.title
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Segmented {
                        Layout.fillWidth: true
                        model: spaceRow.modelData.choices.map((c, i) => ({
                                    "label": c.label,
                                    "value": i
                                }))
                        value: {
                            const have = root.cfg[spaceRow.modelData.key];
                            const at = spaceRow.modelData.choices.findIndex(c => c.value === (have === undefined ? null : have));
                            return at < 0 ? 0 : at;
                        }
                        onSelected: i => root.set(spaceRow.modelData.key, spaceRow.modelData.choices[i].value)
                    }
                }
            }

            // the bars of the sound waves
            Repeater {
                model: root.cfg.type === "waves" ? [
                    {
                        "key": "barWidth",
                        "title": "Bar thickness",
                        "choices": [
                            {
                                "label": "Thin",
                                "value": "thin"
                            },
                            {
                                "label": "Normal",
                                "value": null
                            },
                            {
                                "label": "Thick",
                                "value": "thick"
                            }
                        ]
                    },
                    {
                        "key": "contrast",
                        "title": "Contrast between tones",
                        "choices": [
                            {
                                "label": "Soft",
                                "value": "soft"
                            },
                            {
                                "label": "Normal",
                                "value": null
                            },
                            {
                                "label": "Strong",
                                "value": "strong"
                            }
                        ]
                    },
                    {
                        "key": "barCount",
                        "title": "Number of bars",
                        "choices": [
                            {
                                "label": "Few",
                                "value": 16
                            },
                            {
                                "label": "Normal",
                                "value": null
                            }
                        ]
                    },
                    {
                        "key": "pulse",
                        "title": "Beat pulse",
                        "choices": [
                            {
                                "label": "On",
                                "value": null
                            },
                            {
                                "label": "Off",
                                "value": "off"
                            }
                        ]
                    },
                    {
                        "key": "barShape",
                        "title": "Bar ends",
                        "choices": [
                            {
                                "label": "Round",
                                "value": null
                            },
                            {
                                "label": "Square",
                                "value": "square"
                            }
                        ]
                    }
                ] : []

                ColumnLayout {
                    id: barRow

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: barRow.modelData.title
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Segmented {
                        Layout.fillWidth: true
                        model: barRow.modelData.choices.map((c, i) => ({
                                    "label": c.label,
                                    "value": i
                                }))
                        value: {
                            const have = root.cfg[barRow.modelData.key];
                            const at = barRow.modelData.choices.findIndex(c => c.value === (have === undefined ? null : have));
                            return at < 0 ? 0 : at;
                        }
                        onSelected: i => root.set(barRow.modelData.key, barRow.modelData.choices[i].value)
                    }
                }
            }

            // the numbers: 0123 or Arabic-Indic ٠١٢٣
            ColumnLayout {
                visible: root.cfg.type === "clock" || root.cfg.type === "calendar"
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: "Numbers"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Segmented {
                    Layout.fillWidth: true
                    model: [
                        {
                            "label": "0 1 2 3",
                            "value": "western"
                        },
                        {
                            "label": "٠ ١ ٢ ٣",
                            "value": "arabic"
                        }
                    ]
                    value: root.cfg.numerals === "arabic" ? "arabic" : "western"
                    onSelected: v => root.set("numerals", v === "arabic" ? "arabic" : null)
                }
            }

            // the date, on the clock and the calendar
            ColumnLayout {
                visible: root.cfg.type === "clock" || root.cfg.type === "calendar"
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: "Date"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Segmented {
                    Layout.fillWidth: true
                    model: [
                        {
                            "label": "Show",
                            "value": "shown"
                        },
                        {
                            "label": "Hide",
                            "value": "hidden"
                        }
                    ]
                    value: root.cfg.date === "hidden" ? "hidden" : "shown"
                    onSelected: v => root.set("date", v === "hidden" ? "hidden" : null)
                }
            }

            // colours: the first swatch is the default
            Repeater {
                model: [
                    {
                        "key": "color",
                        "title": "Text colour"
                    },
                    {
                        "key": "accent",
                        "title": "Accent colour"
                    }
                ]

                ColumnLayout {
                    id: colourRow

                    required property var modelData
                    readonly property string current: root.cfg[modelData.key] ?? ""

                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: colourRow.modelData.title
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: root.swatches

                            Rectangle {
                                id: swatch

                                required property string modelData
                                readonly property bool isDefault: modelData === ""
                                readonly property bool picked: colourRow.current.toLowerCase() === modelData

                                width: 30
                                height: 30
                                radius: 15
                                color: isDefault ? Appearance.surfaceHighColor : modelData
                                border.width: picked ? 3 : 1
                                border.color: picked ? Appearance.accentColor : Appearance.outlineColor
                                activeFocusOnTab: true
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                        root.set(colourRow.modelData.key, isDefault ? null : modelData);
                                        event.accepted = true;
                                    }
                                }

                                FocusRing {
                                }

                                // the default one says what it is
                                MaterialSymbol {
                                    visible: swatch.isDefault
                                    anchors.centerIn: parent
                                    icon: "format_color_reset"
                                    font.pixelSize: 17
                                    color: swatch.picked || colourRow.current === "" ? Appearance.accentColor : Appearance.mutedColor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.set(colourRow.modelData.key, swatch.isDefault ? null : swatch.modelData)
                                }
                            }
                        }

                        // any colour: a hex code
                        FieldInput {
                            width: 100
                            height: 30
                            placeholder: "#rrggbb"
                            value: colourRow.current !== "" && root.swatches.indexOf(colourRow.current.toLowerCase()) < 0 ? colourRow.current : ""
                            onCommitted: text => {
                                if (root.isHex(text))
                                    root.set(colourRow.modelData.key, "#" + text.trim().replace("#", "").toLowerCase());
                                else if (text.trim() === "")
                                    root.set(colourRow.modelData.key, null);
                            }
                        }
                    }
                }
            }

            // font: the playful ones are first
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: "Font"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    FieldInput {
                        id: fontSearch

                        Layout.fillWidth: true
                        placeholder: "Search fonts"
                        icon: "search"
                        value: root.fontQuery
                        onEdited: text => root.fontQuery = text
                    }

                    // a font installed a moment ago: the list is also read again each time these options open
                    IconButton {
                        icon: "refresh"
                        iconSize: 20
                        size: 36
                        onClicked: DesktopWidgets.rescanFonts()
                    }
                }

                StyledText {
                    visible: root.fontChoices.length === 0
                    text: "No font matches"
                    color: Appearance.mutedColor
                    font.pixelSize: 13
                }

                Rectangle {
                    visible: root.fontChoices.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: 20
                    color: Appearance.surfaceColor
                    clip: true

                    ListView {
                        id: fontList

                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.fontChoices
                        // open on the font in use
                        Component.onCompleted: {
                            const at = root.fontChoices.indexOf(root.cfg.font ?? "");
                            if (at > 0)
                                positionViewAtIndex(at, ListView.Center);
                        }

                        delegate: Rectangle {
                            id: fontRow

                            required property string modelData
                            required property int index
                            readonly property bool isDefault: modelData === ""
                            readonly property bool picked: (root.cfg.font ?? "") === modelData
                            readonly property bool fun: !isDefault && DesktopWidgets.playful.test(modelData)

                            width: fontList.width
                            height: 36
                            radius: 14
                            color: picked ? Qt.alpha(Appearance.accentColor, 0.22) : fontMouse.containsMouse ? Appearance.surfaceHighColor : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: fontRow.isDefault ? "Default" : fontRow.modelData
                                    font.family: fontRow.isDefault ? Appearance.fontFamily : fontRow.modelData
                                    font.pixelSize: 16
                                }

                                MaterialSymbol {
                                    visible: fontRow.fun
                                    icon: "celebration"
                                    font.pixelSize: 16
                                    color: Appearance.accentColor
                                }

                                MaterialSymbol {
                                    visible: fontRow.picked
                                    icon: "check"
                                    font.pixelSize: 18
                                    color: Appearance.accentColor
                                }
                            }

                            MouseArea {
                                id: fontMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.set("font", fontRow.isDefault ? null : fontRow.modelData)
                            }
                        }
                    }
                }
            }

            // weight, shadow, see-through
            Repeater {
                model: [
                    {
                        "key": "weight",
                        "title": "Weight",
                        "choices": [
                            {
                                "label": "Auto",
                                "value": null
                            },
                            {
                                "label": "Light",
                                "value": Font.Light
                            },
                            {
                                "label": "Regular",
                                "value": Font.Normal
                            },
                            {
                                "label": "Bold",
                                "value": Font.Bold
                            },
                            {
                                "label": "Black",
                                "value": Font.Black
                            }
                        ]
                    },
                    {
                        "key": "shadow",
                        "title": "Shadow",
                        "choices": [
                            {
                                "label": "Off",
                                "value": "off"
                            },
                            {
                                "label": "Soft",
                                "value": null
                            },
                            {
                                "label": "Strong",
                                "value": "strong"
                            }
                        ]
                    },
                    {
                        "key": "opacity",
                        "title": "See-through",
                        "choices": [
                            {
                                "label": "None",
                                "value": null
                            },
                            {
                                "label": "A little",
                                "value": 0.8
                            },
                            {
                                "label": "Half",
                                "value": 0.55
                            },
                            {
                                "label": "Faint",
                                "value": 0.3
                            }
                        ]
                    }
                ]

                ColumnLayout {
                    id: choiceRow

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: choiceRow.modelData.title
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Segmented {
                        Layout.fillWidth: true
                        // an unset key shows as the choice whose value is null (the default)
                        model: choiceRow.modelData.choices.map((c, i) => ({
                                    "label": c.label,
                                    "value": i
                                }))
                        value: {
                            const have = root.cfg[choiceRow.modelData.key];
                            const at = choiceRow.modelData.choices.findIndex(c => c.value === (have === undefined ? null : have));
                            return at < 0 ? 0 : at;
                        }
                        onSelected: i => root.set(choiceRow.modelData.key, choiceRow.modelData.choices[i].value)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                PillButton {
                    text: "Reset to default"
                    icon: "restart_alt"
                    onClicked: DesktopWidgets.resetLook(root.wid)
                }

                Item {
                    Layout.fillWidth: true
                }

                PillButton {
                    text: "Done"
                    toggled: true
                    onClicked: DesktopWidgets.optionsFor = ""
                }
            }
        }
    }
}
