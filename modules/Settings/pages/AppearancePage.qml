import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

SettingsPage {
    id: page

    readonly property var accentColors: ["#EBCB8B", "#c2c1ff", "#ffc1c1", "#c1ffc1", "#d3e3fd", "#ffc1ff", "#c1ffff", "#ffb68d"]
    readonly property var themes: [
        { "name": "Midnight", "bg": "#131317", "fg": "#e5e1e7", "accent": "#c2c1ff" },
        { "name": "Obsidian", "bg": "#0b0b0d", "fg": "#e5e1e7", "accent": "#ebcb8b" },
        { "name": "Tokyo Night", "bg": "#1a1b26", "fg": "#c0caf5", "accent": "#7aa2f7" },
        { "name": "Catppuccin", "bg": "#1e1e2e", "fg": "#cdd6f4", "accent": "#cba6f7" },
        { "name": "Dracula", "bg": "#1e1f29", "fg": "#f8f8f2", "accent": "#bd93f9" }
    ]
    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperName: Config.appearance.wallpaper.split("/").pop()
    // what the reset button next to the opacity slider goes back to
    readonly property real defaultOpacity: 0.5
    property string matchError: ""
    property string matchMode: "dark"
    // palettes made from the wallpaper: [{ key, name, dark: { bg, fg, accent }, light: { … } }]
    property var palettes: []
    // true while the colours are being worked out (including the short wait after a new wallpaper)
    readonly property bool generating: matugenProc.running || wallpaperSettle.running
    // the cards fade in one after another, but only right after they were generated
    property bool revealCards: false
    readonly property var paletteStyles: [
        { "key": "tonal-spot", "name": "Tonal" },
        { "key": "vibrant", "name": "Vibrant" },
        { "key": "expressive", "name": "Expressive" },
        { "key": "fidelity", "name": "Faithful" },
        { "key": "content", "name": "Content" },
        { "key": "neutral", "name": "Neutral" },
        { "key": "rainbow", "name": "Rainbow" },
        { "key": "fruit-salad", "name": "Fruit salad" },
        { "key": "monochrome", "name": "Monochrome" }
    ]

    function expand(path) {
        return path.startsWith("~") ? home + path.substring(1) : path;
    }

    function isHex(text) {
        return /^#[0-9a-f]{6}$/i.test(text);
    }

    function setAccent(c) {
        Config.appearance.accentColor = String(c);
        Config.appearance.accentColorLight = Qt.lighter(c, 1.12).toString();
    }

    function applyTheme(theme) {
        Config.appearance.bgColor = theme.bg;
        Config.appearance.fgColor = theme.fg;
        setAccent(theme.accent);
    }

    // one palette per style, each in dark and light, from the current wallpaper
    function generatePalettes() {
        if (Config.appearance.wallpaper === "" || matugenProc.running)
            return;
        matchError = "";
        matugenProc.command = ["sh", "-c", "p=$1; shift; for t; do printf '%s ' \"$t\"; matugen image \"$p\" -t \"scheme-$t\" -j hex --dry-run -q 2>/dev/null | tr -d '\\n '; echo; done", "sh", Config.appearance.wallpaper].concat(paletteStyles.map(st => st.key));
        matugenProc.running = true;
    }

    // two colour sets that are the same: background, text and accent match (within 2/255 per channel, i.e. rounding)
    function sameLook(a, b) {
        for (const key of ["bg", "fg", "accent"]) {
            const x = Qt.color(String(a[key]));
            const y = Qt.color(String(b[key]));
            if (Math.max(Math.abs(x.r - y.r), Math.abs(x.g - y.g), Math.abs(x.b - y.b)) * 255 > 2)
                return false;
        }
        return true;
    }

    // the colours in use right now
    function currentColors() {
        return {
            "bg": Appearance.bgColor,
            "fg": Appearance.fgColor,
            "accent": Appearance.accentColor
        };
    }

    // switch the whole theme to dark or light at once: the style in use keeps its look,
    // from a preset theme the first style (Tonal) is used
    function setMode(mode) {
        matchMode = mode;
        if (palettes.length === 0)
            return;
        const now = currentColors();
        const inUse = palettes.find(p => sameLook(p.dark, now) || sameLook(p.light, now)) || palettes[0];
        applyTheme(inUse[mode]);
    }

    // styles that come out exactly the same for this wallpaper are shown once; slightly different ones all stay
    readonly property var shownPalettes: {
        const kept = [];
        for (const p of palettes) {
            if (!kept.some(k => sameLook(k[matchMode], p[matchMode])))
                kept.push(p);
        }
        return kept;
    }
    // the one card that matches the colours in use (only ever one tick)
    readonly property int currentIndex: {
        const now = {
            "bg": Appearance.bgColor,
            "fg": Appearance.fgColor,
            "accent": Appearance.accentColor
        };
        return shownPalettes.findIndex(p => sameLook(p[matchMode], now));
    }

    // colour being edited in the picker: "accent", "bg" or "fg"
    property string pickTarget: ""

    // opens the colour picker for "accent", "bg" or "fg"
    function pickColor(target) {
        pickTarget = target;
        const current = target === "accent" ? Appearance.accentColor : (target === "bg" ? Appearance.bgColor : Appearance.fgColor);
        colorPicker.openWith(current, target === "accent" ? "Accent colour" : (target === "bg" ? "Background colour" : "Text colour"));
    }

    function applyColor(target, c) {
        // the shell's colours are opaque: drop any alpha the picker added
        const hex = Qt.rgba(c.r, c.g, c.b, 1).toString();
        if (target === "accent")
            setAccent(hex);
        else if (target === "bg")
            Config.appearance.bgColor = hex;
        else
            Config.appearance.fgColor = hex;
    }

    title: "Appearance"

    ColorPicker {
        id: colorPicker

        swatches: page.accentColors
        recents: Config.recentColors || []
        // the theme follows while you pick; Cancel puts the old colour back
        onPreviewed: c => page.applyColor(page.pickTarget, c)
        onApplied: c => Config.addRecentColor(c.toString())
        onCancelled: page.applyColor(page.pickTarget, colorPicker.original)
    }

    FileDialog {
        id: wallpaperDialog

        title: "Choose desktop and lock screen wallpaper"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: Config.appearance.wallpaper = selectedFile.toString().replace("file://", "")
    }

    FolderDialog {
        id: folderDialog

        title: "Choose the wallpaper folder"
        onAccepted: Config.appearance.wallpaperDir = decodeURIComponent(selectedFolder.toString().replace("file://", ""))
    }

    FolderListModel {
        id: wallpapers

        folder: "file://" + page.expand(Config.appearance.wallpaperDir)
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        caseSensitive: false
        showDirs: false
    }

    // colours from the wallpaper (Material You), via matugen
    Process {
        id: matugenProc

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const space = line.indexOf(" ");
                    if (space < 0)
                        continue;
                    const key = line.substring(0, space);
                    try {
                        const colors = JSON.parse(line.substring(space + 1)).colors;
                        const style = page.paletteStyles.find(st => st.key === key);
                        const pick = mode => ({
                            "bg": colors.surface[mode],
                            "fg": colors.on_surface[mode],
                            "accent": colors.primary[mode]
                        });
                        found.push({
                            "key": key,
                            "name": style ? style.name : key,
                            "dark": pick("dark"),
                            "light": pick("light")
                        });
                    } catch (e) {
                    }
                }
                page.revealCards = true;
                revealEnd.restart();
                page.palettes = found;
                // show the cards in the mode the theme is already in
                const now = page.currentColors();
                if (found.some(p => page.sameLook(p.light, now)))
                    page.matchMode = "light";
                else if (found.some(p => page.sameLook(p.dark, now)))
                    page.matchMode = "dark";
                if (found.length === 0)
                    page.matchError = "Couldn't read colours from the wallpaper. Is matugen installed?";
            }
        }
    }

    // new wallpaper, new palettes
    Connections {
        function onWallpaperChanged() {
            page.palettes = [];
            wallpaperSettle.restart();
        }

        target: Config.appearance
    }

    // the staggered fade-in plays once per generation, not on every Dark/Light flip
    Timer {
        id: revealEnd

        interval: 1200
        onTriggered: page.revealCards = false
    }

    Timer {
        id: wallpaperSettle

        interval: 300
        onTriggered: page.generatePalettes()
    }

    Component.onCompleted: generatePalettes()

    // pick the accent from any pixel on screen
    Process {
        id: pickerProc

        command: ["hyprpicker"]

        stdout: StdioCollector {
            onStreamFinished: {
                const picked = text.trim();
                if (page.isHex(picked))
                    page.setAccent(picked);
            }
        }
    }

    SettingGroup {
        title: "Wallpaper"

        SettingRow {
            icon: "image"
            title: Config.appearance.wallpaper ? page.wallpaperName : "No wallpaper"
            description: "Shared by the desktop and the lock screen"

            PillButton {
                text: "Browse…"
                onClicked: wallpaperDialog.open()
            }

            PillButton {
                visible: Config.appearance.wallpaper !== ""
                text: "Clear"
                onClicked: Config.appearance.wallpaper = ""
            }
        }

        SettingCard {
            visible: wallpapers.count > 0

            ListView {
                id: strip

                Layout.fillWidth: true
                implicitHeight: 90
                orientation: ListView.Horizontal
                model: wallpapers
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 600

                delegate: ClippingRectangle {
                    id: thumb

                    required property string filePath
                    required property url fileUrl
                    readonly property bool current: Config.appearance.wallpaper === filePath

                    width: 144
                    height: 90
                    radius: 14
                    color: Appearance.surfaceHighColor

                    Image {
                        anchors.fill: parent
                        source: thumb.fileUrl
                        sourceSize.width: 288
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: thumbArea.containsMouse && !thumb.current ? Qt.alpha(Appearance.fgColor, 0.12) : "transparent"
                        border.width: thumb.current ? 3 : 0
                        border.color: Appearance.accentColor
                    }

                    MouseArea {
                        id: thumbArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.appearance.wallpaper = thumb.filePath
                    }
                }
            }
        }

        SettingRow {
            icon: "folder"
            title: "Wallpaper folder"
            description: wallpapers.count > 0 ? wallpapers.count + " images shown above" : "No images found in this folder"

            FieldInput {
                implicitWidth: 240
                value: Config.appearance.wallpaperDir
                onCommitted: text => Config.appearance.wallpaperDir = text.trim()
            }

            IconButton {
                icon: "folder_open"
                onClicked: folderDialog.open()
            }
        }
    }

    SettingGroup {
        title: "Theme"

        SettingCard {
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: page.themes

                    delegate: Rectangle {
                        id: chip

                        required property var modelData
                        readonly property bool current: Qt.colorEqual(Appearance.bgColor, modelData.bg) && Qt.colorEqual(Appearance.fgColor, modelData.fg) && Qt.colorEqual(Appearance.accentColor, modelData.accent)

                        width: chipRow.implicitWidth + 26
                        height: 40
                        radius: 20
                        color: modelData.bg
                        border.width: current ? 2 : 1
                        border.color: current ? Appearance.accentColor : Appearance.outlineColor
                        scale: chipArea.pressed ? 0.96 : 1

                        RowLayout {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: chip.modelData.accent
                            }

                            StyledText {
                                text: chip.modelData.name
                                color: chip.modelData.fg
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: chipArea

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.applyTheme(chip.modelData)
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animFast
                            }
                        }
                    }
                }
            }
        }

        SettingRow {
            visible: Config.appearance.wallpaper !== ""
            icon: "auto_awesome"
            title: "Palettes from the wallpaper"
            description: page.matchError !== "" ? page.matchError : (matugenProc.running ? "Working out colours from " + page.wallpaperName + "…" : "Pick one of the styles below, made from " + page.wallpaperName)

            Segmented {
                model: [
                    {
                        "label": "Dark",
                        "value": "dark"
                    },
                    {
                        "label": "Light",
                        "value": "light"
                    }
                ]
                value: page.matchMode
                onSelected: mode => page.setMode(mode)
            }

            IconButton {
                enabled: !matugenProc.running
                icon: "refresh"
                onClicked: page.generatePalettes()
            }
        }

        SettingCard {
            visible: Config.appearance.wallpaper !== "" && (page.generating || page.shownPalettes.length > 0)

            // spinner while the palettes are being made
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                visible: page.generating
                spacing: 14

                Item {
                    Layout.leftMargin: 6
                    implicitWidth: 30
                    implicitHeight: 30

                    MaterialSymbol {
                        id: spinner

                        anchors.centerIn: parent
                        icon: "progress_activity"
                        font.pixelSize: 30
                        color: Appearance.accentColor

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            running: page.generating
                        }
                    }
                }

                ColumnLayout {
                    spacing: 1

                    StyledText {
                        text: "Generating palettes"
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: "From " + page.wallpaperName
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: !page.generating
                spacing: 10

                Repeater {
                    model: page.shownPalettes

                    delegate: Rectangle {
                        id: card

                        required property var modelData
                        required property int index
                        readonly property var colors: modelData[page.matchMode]
                        readonly property bool current: index === page.currentIndex

                        width: 150
                        height: 92
                        radius: 18
                        color: colors.bg
                        border.width: current ? 2 : 1
                        border.color: current ? colors.accent : Qt.alpha(colors.fg, 0.2)
                        scale: cardArea.pressed ? 0.97 : (cardArea.containsMouse ? 1.03 : 1)

                        // fade and rise in, one card after the other
                        property real rise: 0

                        transform: Translate {
                            y: card.rise
                        }

                        Component.onCompleted: {
                            if (page.revealCards)
                                reveal.start();
                        }

                        SequentialAnimation {
                            id: reveal

                            ScriptAction {
                                script: {
                                    card.opacity = 0;
                                    card.rise = 12;
                                }
                            }

                            PauseAnimation {
                                duration: card.index * 70
                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: card
                                    property: "opacity"
                                    to: 1
                                    duration: Appearance.animNormal
                                }

                                NumberAnimation {
                                    target: card
                                    property: "rise"
                                    to: 0
                                    duration: Appearance.animSlow
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.easeOut
                                }
                            }
                        }

                        StyledText {
                            x: 14
                            y: 10
                            text: "Aa"
                            color: card.colors.fg
                            font.pixelSize: 24
                            font.weight: Font.Bold
                        }

                        // accent swatch, as it looks on active tiles and sliders
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            width: 46
                            height: 22
                            radius: 11
                            color: card.colors.accent
                        }

                        StyledText {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 12
                            text: card.modelData.name
                            color: card.colors.fg
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        MaterialSymbol {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            visible: card.current
                            icon: "check_circle"
                            fill: 1
                            font.pixelSize: 20
                            color: card.colors.accent
                        }

                        MouseArea {
                            id: cardArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.applyTheme(card.colors)
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animFast
                            }
                        }
                    }
                }
            }
        }
    }

    SettingGroup {
        title: "Colours"

        SettingRow {
            title: "Accent"
            description: "Active tiles, sliders and highlights"

            Repeater {
                model: page.accentColors

                delegate: Rectangle {
                    id: swatch

                    required property color modelData
                    readonly property bool current: Qt.colorEqual(Appearance.accentColor, modelData)

                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 13
                    color: modelData
                    scale: swatchArea.pressed ? 0.9 : (swatchArea.containsMouse ? 1.1 : 1)

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: swatch.current
                        icon: "check"
                        font.pixelSize: 16
                        color: "#1b1b1f"
                    }

                    MouseArea {
                        id: swatchArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.setAccent(swatch.modelData)
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Custom accent"
            description: "Click the circle to pick any colour, type a hex code, or sample one from the screen"

            ColorWell {
                onClicked: page.pickColor("accent")
                color: Appearance.accentColor
            }

            FieldInput {
                implicitWidth: 110
                value: Config.appearance.accentColor
                placeholder: "#rrggbb"
                onCommitted: text => {
                    if (page.isHex(text.trim()))
                        page.setAccent(text.trim());
                }
            }

            IconButton {
                icon: "colorize"
                onClicked: pickerProc.running = true
            }
        }

        SettingRow {
            title: "Background"
            description: "Bar, panels and windows · click the circle to pick"

            ColorWell {
                onClicked: page.pickColor("bg")
                color: Appearance.bgColor
            }

            FieldInput {
                implicitWidth: 110
                value: Config.appearance.bgColor
                placeholder: "#rrggbb"
                onCommitted: text => {
                    if (page.isHex(text.trim()))
                        Config.appearance.bgColor = text.trim();
                }
            }
        }

        SettingRow {
            title: "Text"
            description: "Text and icons; surfaces are tinted with it · click the circle to pick"

            ColorWell {
                onClicked: page.pickColor("fg")
                color: Appearance.fgColor
            }

            FieldInput {
                implicitWidth: 110
                value: Config.appearance.fgColor
                placeholder: "#rrggbb"
                onCommitted: text => {
                    if (page.isHex(text.trim()))
                        Config.appearance.fgColor = text.trim();
                }
            }
        }
    }

    SettingGroup {
        title: "Interface"

        SettingRow {
            icon: "opacity"
            title: "Panel opacity"
            description: "How see-through the bar and panels are · the desktop behind stays blurred until 0%"

            IconButton {
                // back to the default
                visible: Math.abs(Appearance.panelOpacity - page.defaultOpacity) > 0.004
                icon: "restart_alt"
                onClicked: Config.appearance.opacity = page.defaultOpacity
            }

            StyledText {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round(Appearance.panelOpacity * 100) + "%"
                font.weight: Font.Medium
            }

            PillSlider {
                implicitWidth: 260
                implicitHeight: 36
                icon: "opacity"
                // 0% is fully clear; from 1% up the desktop behind is blurred
                value: Appearance.panelOpacity
                onDragged: v => Config.appearance.opacity = Math.round(v * 100) / 100
            }
        }

        SettingRow {
            icon: "text_fields"
            title: "Font"
            description: "Used for all text in the shell"

            Dropdown {
                model: Qt.fontFamilies()
                value: Config.appearance.fontFamily
                placeholder: Config.appearance.fontFamily
                searchable: true
                popupWidth: 300
                onSelected: family => Config.appearance.fontFamily = family
            }
        }
    }
}
