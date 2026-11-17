import "../../components"
import "../../config"
import "../../services/"
import "./pages"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

ApplicationWindow {
    id: root

    // keywords are what the sidebar search matches besides the name
    readonly property var pages: [
        {
            "key": "wifi",
            "name": "Network",
            "icon": "wifi",
            "group": "Connections",
            "keywords": "wifi wi-fi internet wireless password ip address ethernet wired cable lan",
            "component": wifiPage
        },
        {
            "key": "bluetooth",
            "name": "Bluetooth",
            "icon": "bluetooth",
            "group": "Connections",
            "available": Bluetooth.available,
            "keywords": "devices pair headphones discoverable",
            "component": bluetoothPage
        },
        {
            "key": "sound",
            "name": "Sound",
            "icon": "volume_up",
            "group": "Device",
            "keywords": "audio volume output input microphone speaker mute applications",
            "component": soundPage
        },
        {
            "key": "display",
            "name": "Display",
            "icon": "desktop_windows",
            "group": "Device",
            "keywords": "brightness night light temperature monitor screen resolution scale",
            "component": displayPage
        },
        {
            "key": "power",
            "name": "Power",
            "icon": "bolt",
            "group": "Device",
            "keywords": "battery profile performance saver suspend restart shut down log out session",
            "component": powerPage
        },
        {
            "key": "keyboard",
            "name": "Keyboard",
            "icon": "keyboard",
            "group": "Device",
            "keywords": "layout language input labels arabic english switch shortcut variant",
            "component": keyboardPage
        },
        {
            "key": "printers",
            "name": "Printers",
            "icon": "print",
            "group": "Device",
            "available": Printers.printers.length > 0 || Printers.scanners.length > 0,
            "keywords": "printer scanner print scan cups queue ink toner test page default sane",
            "component": printersPage
        },
        {
            "key": "storage",
            "name": "Storage",
            "icon": "hard_drive",
            "group": "Device",
            "keywords": "drive disk usb flash sd card mount unmount eject partition nvme ssd health smart",
            "component": storagePage
        },
        {
            "key": "hyprland",
            "name": "Hyprland",
            "icon": "window",
            "logo": true,
            "group": "Device",
            "keywords": "mouse touchpad trackpad tablet pen touch screen gestures swipe scroll sensitivity window manager compositor border gaps rounding blur shadow opacity animations input touchpad cursor layout dwindle master workspace gestures lua conf",
            "component": hyprlandPage
        },
        {
            "key": "autocomplete",
            "name": "Autocomplete",
            "icon": "spellcheck",
            "experimental": true,
            "group": "Device",
            "keywords": "suggestions predictive text typing words completion arabic english dictionary input method",
            "component": autocompletePage
        },
        {
            "key": "accounts",
            "name": "Accounts",
            "icon": "account_circle",
            "group": "Personalisation",
            "keywords": "user profile picture avatar name password hostname computer name shell groups google microsoft nextcloud online account email login",
            "component": accountsPage
        },
        {
            "key": "appearance",
            "name": "Appearance",
            "icon": "palette",
            "group": "Personalisation",
            "keywords": "wallpaper theme accent colour color background text opacity font transparency",
            "component": appearancePage
        },
        {
            "key": "fonts",
            "name": "Fonts",
            "icon": "match_case",
            "group": "Personalisation",
            "keywords": "font typeface text family serif sans monospace arabic language gtk terminal emoji size",
            "component": fontsPage
        },
        {
            "key": "bar",
            "name": "Bar & dock",
            "icon": "dock_to_right",
            "group": "Personalisation",
            "keywords": "position left right clock 24 hour pinned apps",
            "component": barPage
        },
        {
            "key": "notifications",
            "name": "Notifications",
            "icon": "notifications",
            "group": "Personalisation",
            "keywords": "do not disturb dnd toast popup duration clear",
            "component": notificationsPage
        },
        {
            "key": "lock",
            "name": "Lock & idle",
            "icon": "lock",
            "group": "Personalisation",
            "keywords": "lock screen auto idle timeout displays off pause",
            "component": lockPage
        },
        {
            "key": "launcher",
            "name": "Launcher",
            "icon": "search",
            "group": "Tools",
            "keywords": "search browser bangs web engine private usage history",
            "component": launcherPage
        },
        {
            "key": "capture",
            "name": "Clipboard & capture",
            "icon": "content_paste",
            "group": "Tools",
            "keywords": "clipboard history paste screenshot recording folder audio",
            "component": capturePage
        },
        {
            "key": "datetime",
            "name": "Date, time & region",
            "icon": "schedule",
            "group": "System",
            "keywords": "clock time zone timezone ntp automatic 24 hour 12 language locale region format calendar date country units",
            "component": dateTimePage
        },
        {
            "key": "startup",
            "name": "Startup apps",
            "icon": "rocket_launch",
            "group": "System",
            "keywords": "startup autostart login boot start apps programs session launch",
            "component": startupPage
        },
        {
            "key": "defaults",
            "name": "Default apps",
            "icon": "open_in_new",
            "group": "System",
            "keywords": "default apps browser file manager email mime open with images video music pdf text associations",
            "component": defaultAppsPage
        },
        {
            "key": "system",
            "name": "System",
            "icon": "memory",
            "group": "System",
            "keywords": "cpu processor memory ram storage disk temperature gpu graphics uptime kernel",
            "component": systemPage
        },
        {
            "key": "about",
            "name": "About",
            "icon": "info",
            "group": "System",
            "keywords": "version config file reload dependencies tools ipc keybind",
            "component": aboutPage
        }
    ]
    // the launcher finds these pages
    Binding {
        target: WindowManager
        property: "settingsIndex"
        value: root.pages.filter(p => p.available !== false).map(p => ({
                    "key": p.key,
                    "name": p.name,
                    "icon": p.icon,
                    "group": p.group,
                    "keywords": p.keywords
                }))
    }

    property string currentKey: "wifi"
    property string query: ""
    readonly property var shownPages: {
        const q = query.trim().toLowerCase();
        // pages for hardware this computer does not have are left out
        const present = pages.filter(p => p.available !== false);
        if (q === "")
            return present;
        return present.filter(p => (p.name + " " + p.keywords).toLowerCase().includes(q));
    }

    function showPage(name) {
        const wanted = String(name || "").toLowerCase();
        if (wanted === "")
            return;
        const page = pages.find(p => p.key === wanted || p.name.toLowerCase() === wanted);
        if (page)
            currentKey = page.key;
    }

    width: 980
    height: 680
    minimumWidth: 720
    minimumHeight: 440
    title: "Settings"
    visible: WindowManager.settingsVisible
    // light themes get the same stronger tint as the panels, or the blur turns them dull grey
    color: Qt.alpha(Appearance.bgColor, Appearance.isLight ? 1 - Math.pow(1 - Config.appearance.settingsOpacity, 2) : Config.appearance.settingsOpacity)
    onClosing: WindowManager.settingsVisible = false
    onVisibleChanged: {
        if (visible && WindowManager.settingsPage !== "") {
            showPage(WindowManager.settingsPage);
            WindowManager.settingsPage = "";
        }
    }

    Connections {
        function onSettingsPageChanged() {
            if (WindowManager.settingsPage !== "" && root.visible) {
                root.showPage(WindowManager.settingsPage);
                WindowManager.settingsPage = "";
            }
        }

        target: WindowManager
    }

    // qs ipc call settings toggle | open | close | page <name>
    IpcHandler {
        function toggle(): void {
            WindowManager.settingsVisible = !WindowManager.settingsVisible;
        }

        function open(): void {
            WindowManager.openSettings("");
        }

        function close(): void {
            WindowManager.settingsVisible = false;
        }

        function page(name: string): void {
            WindowManager.openSettings(name);
        }

        target: "settings"
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: search.focusInput()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.query !== ""
        onActivated: {
            search.clear();
            root.query = "";
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // --- sidebar: fixed width, the page area takes the rest ---
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 232
            Layout.minimumWidth: 232
            Layout.maximumWidth: 232
            Layout.fillHeight: true
            Layout.margins: 12
            spacing: 10

            StyledText {
                Layout.leftMargin: 12
                Layout.topMargin: 10
                text: "Settings"
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            FieldInput {
                id: search

                Layout.fillWidth: true
                icon: "search"
                placeholder: "Search settings"
                onEdited: text => root.query = text
                onAccepted: {
                    if (root.shownPages.length > 0) {
                        root.currentKey = root.shownPages[0].key;
                        search.clear();
                        root.query = "";
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: nav.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: nav

                    width: parent.width
                    spacing: 3

                    Repeater {
                        model: root.shownPages

                        delegate: ColumnLayout {
                            id: navEntry

                            required property var modelData
                            required property int index
                            readonly property bool current: root.currentKey === modelData.key
                            readonly property color contentColor: current ? Appearance.accentContrastColor : Appearance.fgColor
                            // group heading above the first page of each group (not while searching)
                            readonly property bool startsGroup: root.query.trim() === "" && (index === 0 || root.shownPages[index - 1].group !== modelData.group)

                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.leftMargin: 14
                                Layout.topMargin: navEntry.index === 0 ? 2 : 12
                                Layout.bottomMargin: 2
                                visible: navEntry.startsGroup
                                text: navEntry.modelData.group
                                color: Appearance.mutedColor
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 40
                                radius: 20
                                color: navEntry.current ? Appearance.accentColor : (navArea.containsMouse ? Appearance.surfaceColor : "transparent")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    MaterialSymbol {
                                        visible: navEntry.modelData.logo !== true
                                        icon: navEntry.modelData.icon
                                        fill: navEntry.current ? 1 : 0
                                        font.pixelSize: 20
                                        color: navEntry.contentColor
                                    }

                                    // a page with its own logo (Hyprland)
                                    HyprlandLogo {
                                        visible: navEntry.modelData.logo === true
                                        size: 20
                                        color: navEntry.contentColor
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: navEntry.modelData.name
                                        elide: Text.ElideRight
                                        font.weight: Font.Medium
                                        color: navEntry.contentColor
                                    }

                                    // marks a page whose feature is still experimental
                                    MaterialSymbol {
                                        visible: navEntry.modelData.experimental === true
                                        icon: "science"
                                        font.pixelSize: 17
                                        color: navEntry.current ? navEntry.contentColor : Appearance.mutedColor
                                    }
                                }

                                MouseArea {
                                    id: navArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentKey = navEntry.modelData.key
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
                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        visible: root.shownPages.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: "No settings match"
                        color: Appearance.mutedColor
                        font.pixelSize: 13
                    }
                }
            }
        }

        // --- page area ---
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
            Layout.leftMargin: 0
            radius: 24
            color: Appearance.surfaceColor
            clip: true

            Repeater {
                model: root.pages

                // a page only exists while it is shown, so its timers and
                // background commands stop when you leave it or close the window
                delegate: Loader {
                    id: pageLoader

                    required property var modelData
                    readonly property bool current: root.currentKey === modelData.key

                    anchors.fill: parent
                    active: root.visible && (current || opacity > 0)
                    sourceComponent: modelData.component
                    visible: opacity > 0
                    opacity: current ? 1 : 0

                    // fade + small rise when a page becomes current
                    transform: Translate {
                        y: pageLoader.current ? 0 : 10

                        Behavior on y {
                            NumberAnimation {
                                duration: Appearance.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.easeOut
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }
            }
        }
    }

    Component {
        id: wifiPage

        WifiPage {
        }
    }

    Component {
        id: bluetoothPage

        BluetoothPage {
        }
    }

    Component {
        id: soundPage

        SoundPage {
        }
    }

    Component {
        id: displayPage

        DisplayPage {
        }
    }

    Component {
        id: powerPage

        PowerPage {
        }
    }

    Component {
        id: keyboardPage

        KeyboardPage {
        }
    }

    Component {
        id: accountsPage

        AccountsPage {
        }
    }

    Component {
        id: dateTimePage

        DateTimePage {
        }
    }

    Component {
        id: fontsPage

        FontsPage {
        }
    }

    Component {
        id: printersPage

        PrintersPage {
        }
    }

    Component {
        id: storagePage

        StoragePage {
        }
    }

    Component {
        id: startupPage

        StartupPage {
        }
    }

    Component {
        id: defaultAppsPage

        DefaultAppsPage {
        }
    }

    Component {
        id: hyprlandPage

        HyprlandPage {
        }
    }

    Component {
        id: autocompletePage

        AutocompletePage {
        }
    }

    Component {
        id: appearancePage

        AppearancePage {
        }
    }

    Component {
        id: barPage

        BarPage {
        }
    }

    Component {
        id: notificationsPage

        NotificationsPage {
        }
    }

    Component {
        id: lockPage

        LockPage {
        }
    }

    Component {
        id: launcherPage

        LauncherPage {
        }
    }

    Component {
        id: capturePage

        CapturePage {
        }
    }

    Component {
        id: systemPage

        SystemPage {
        }
    }

    Component {
        id: aboutPage

        AboutPage {
        }
    }
}
