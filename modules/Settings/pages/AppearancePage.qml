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
        { "name": "Dracula", "bg": "#1e1f29", "fg": "#f8f8f2", "accent": "#bd93f9" },
        { "name": "GitHub Dark", "bg": "#0d1117", "fg": "#e6edf3", "accent": "#58a6ff" },
        { "name": "Ayu", "bg": "#0b0e14", "fg": "#e6e1cf", "accent": "#ffb454" },
        { "name": "Carbon", "bg": "#0d0d0f", "fg": "#f2f2f2", "accent": "#4c8dff" },
        { "name": "Ocean", "bg": "#08101a", "fg": "#e3edf7", "accent": "#38bdf8" },
        { "name": "Emerald", "bg": "#0a100d", "fg": "#e6f2ec", "accent": "#34d399" },
        { "name": "Amethyst", "bg": "#0e0b14", "fg": "#ece6f7", "accent": "#a78bfa" },
        { "name": "Sakura", "bg": "#140c11", "fg": "#f7e6ef", "accent": "#ff7eb6" },
        { "name": "Crimson", "bg": "#100a0c", "fg": "#f5e6ea", "accent": "#ff4d6d" },
        { "name": "Ember", "bg": "#110c0b", "fg": "#f5e9e4", "accent": "#ff6b3d" },
        { "name": "Solar", "bg": "#12100a", "fg": "#f5efdc", "accent": "#ffc233" },
        { "name": "Mono", "bg": "#0a0a0a", "fg": "#f5f5f5", "accent": "#ffffff" },
        { "name": "Snow", "bg": "#f7f7f8", "fg": "#18181b", "accent": "#2563eb" }
    ]
    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperName: Config.appearance.wallpaper.split("/").pop()
    // what the reset button next to the opacity slider goes back to
    readonly property real defaultOpacity: 0.5
    property string matchError: ""
    property string matchMode: "dark"

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

    function matchWallpaper(mode) {
        matchError = "";
        matchMode = mode;
        matugenProc.exec(["matugen", "image", Config.appearance.wallpaper, "-m", mode, "-j", "hex", "--dry-run", "-q"]);
    }

    // opens the colour picker for "accent", "bg" or "fg"
    function pickColor(target) {
        colorDialog.target = target;
        colorDialog.selectedColor = target === "accent" ? Appearance.accentColor : (target === "bg" ? Appearance.bgColor : Appearance.fgColor);
        colorDialog.open();
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

    ColorDialog {
        id: colorDialog

        property string target: "accent"

        title: target === "accent" ? "Accent colour" : (target === "bg" ? "Background colour" : "Text colour")
        onAccepted: page.applyColor(target, selectedColor)
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
                try {
                    const colors = JSON.parse(text).colors;
                    const mode = page.matchMode;
                    page.applyTheme({
                        "bg": colors.surface[mode],
                        "fg": colors.on_surface[mode],
                        "accent": colors.primary[mode]
                    });
                } catch (e) {
                    page.matchError = "Couldn't read colours from the wallpaper. Is matugen installed?";
                }
            }
        }
    }

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
            title: "Match the wallpaper"
            description: page.matchError !== "" ? page.matchError : "Take background, text and accent colours from " + page.wallpaperName

            PillButton {
                enabled: !matugenProc.running
                text: "Dark"
                onClicked: page.matchWallpaper("dark")
            }

            PillButton {
                enabled: !matugenProc.running
                text: "Light"
                onClicked: page.matchWallpaper("light")
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
            description: "How see-through the bar and panels are"

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
                // slider covers 35% – 100%
                value: (Appearance.panelOpacity - 0.35) / 0.65
                onDragged: v => Config.appearance.opacity = Math.round((0.35 + v * 0.65) * 100) / 100
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
