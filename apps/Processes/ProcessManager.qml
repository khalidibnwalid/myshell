import "../../components"
import "../../config"
import "../../services/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The running processes in their own window: what they use, and ending them.
// bind = $mainMod, Escape, global, quickshell:processes
ApplicationWindow {
    id: root

    // the rows shown; kept here so the list keeps its place when a new sample arrives
    property var rows: []
    property string selectedKey: ""
    readonly property var selectedRow: rows.find(r => r.key === selectedKey) ?? null
    // a busy program, as the System page marks a hot one
    readonly property color hot: "#f2b8b5"
    readonly property bool canEnd: selectedRow !== null && !Processes.protectedRow(selectedRow)

    function openWindow() {
        WindowManager.openProcesses();
    }

    function formatBytes(bytes) {
        return SystemInfo.formatBytes(bytes);
    }

    function formatCpu(value) {
        return value < 0.05 ? "0%" : (value < 10 ? value.toFixed(1) : Math.round(value)) + "%";
    }

    function taken() {
        const y = list.contentY;
        rows = Processes.list;
        list.contentY = Math.min(y, Math.max(0, list.contentHeight - list.height));
    }

    width: 900
    height: 640
    minimumWidth: 560
    minimumHeight: 360
    title: "Processes"
    visible: WindowManager.processesVisible
    color: Qt.alpha(Appearance.bgColor, Appearance.isLight ? 1 - Math.pow(1 - Config.appearance.settingsOpacity, 2) : Config.appearance.settingsOpacity)
    onClosing: WindowManager.processesVisible = false
    onVisibleChanged: {
        Processes.active = visible;
        if (visible) {
            SystemInfo.refresh();
            SystemInfo.refreshLive();
            search.focusInput();
        }
    }

    Connections {
        function onListChanged() {
            root.taken();
        }

        target: Processes
    }

    Connections {
        function onProcessesRaiseRequested() {
            root.raise();
            root.requestActivate();
        }

        target: WindowManager
    }

    // keeps the summary numbers moving while the window is open
    Timer {
        interval: 2000
        repeat: true
        running: root.visible
        onTriggered: SystemInfo.refreshLive()
    }

    GlobalShortcut {
        name: "processes"
        onPressed: WindowManager.processesVisible = !WindowManager.processesVisible
    }

    // qs ipc call processes toggle | open | close
    IpcHandler {
        function toggle(): void {
            if (WindowManager.processesVisible)
                WindowManager.processesVisible = false;
            else
                root.openWindow();
        }

        function open(): void {
            root.openWindow();
        }

        function close(): void {
            WindowManager.processesVisible = false;
        }

        target: "processes"
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: search.focusInput()
    }

    Shortcut {
        sequence: "Delete"
        enabled: root.canEnd && !search.inputItem.activeFocus
        onActivated: Processes.end(root.selectedRow, false)
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (search.text !== "")
                search.clear();
            else
                WindowManager.processesVisible = false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // --- title bar: what the computer is doing, and the actions ---
        RowLayout {
            Layout.fillWidth: true
            // the title bar never makes the window's content wider than the window
            Layout.minimumWidth: 0
            spacing: 8

            StyledText {
                Layout.leftMargin: 6
                text: "Processes"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.leftMargin: 8
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                text: "CPU " + Math.round(SystemInfo.cpuUsage * 100) + "%  ·  Memory " + SystemInfo.formatCapacityRatio(SystemInfo.memoryUsed, SystemInfo.memoryTotal) + "  ·  " + Processes.count + " running"
                color: Appearance.mutedColor
                font.pixelSize: 13
            }

            Segmented {
                model: [
                    {
                        "label": "Mine",
                        "value": true
                    },
                    {
                        "label": "All users",
                        "value": false
                    }
                ]
                value: Processes.onlyMine
                onSelected: v => Processes.onlyMine = v
            }

            Segmented {
                model: [
                    {
                        "label": "Programs",
                        "value": true
                    },
                    {
                        "label": "Processes",
                        "value": false
                    }
                ]
                value: Processes.grouped
                onSelected: v => Processes.grouped = v
            }

            IconButton {
                icon: "close_small"
                size: 36
                enabled: root.canEnd
                opacity: enabled ? 1 : 0.35
                onClicked: Processes.end(root.selectedRow, false)

                ToolTip.visible: hovered
                ToolTip.text: "End (ask it to quit)"
            }

            IconButton {
                icon: "dangerous"
                size: 36
                enabled: root.canEnd
                opacity: enabled ? 1 : 0.35
                color: "#ff5f5f"
                onClicked: Processes.end(root.selectedRow, true)

                ToolTip.visible: hovered
                ToolTip.text: "Force quit (stops it at once)"
            }

            IconButton {
                icon: "close"
                size: 36
                onClicked: WindowManager.processesVisible = false
            }
        }

        FieldInput {
            id: search

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            icon: "search"
            placeholder: "Search by name, command or number"
            onEdited: text => Processes.query = text
        }

        // --- column titles: click one to sort by it ---
        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 60
            Layout.rightMargin: 18
            spacing: 8

            Repeater {
                model: [
                    {
                        "key": "name",
                        "label": "Name",
                        "width": 0
                    },
                    {
                        "key": "cpu",
                        "label": "CPU",
                        "width": 80
                    },
                    {
                        "key": "mem",
                        "label": "Memory",
                        "width": 100
                    },
                    {
                        "key": "pid",
                        "label": Processes.grouped ? "First PID" : "PID",
                        "width": 80
                    }
                ]

                Item {
                    id: head

                    required property var modelData
                    readonly property bool current: Processes.sortKey === modelData.key

                    Layout.fillWidth: modelData.width === 0
                    Layout.preferredWidth: modelData.width
                    implicitHeight: 24

                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: head.modelData.label + (head.current ? (Processes.sortDescending ? "  ↓" : "  ↑") : "")
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: head.current ? Appearance.accentColor : Appearance.mutedColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Processes.sortBy(head.modelData.key)
                    }
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows
            ScrollBar.vertical: ScrollBar {
            }

            delegate: ListRow {
                id: row

                required property var modelData
                required property int index
                readonly property bool busy: modelData.cpu >= 50

                // the program's own icon, or a symbol when it has none
                readonly property string appIcon: {
                    const icon = DesktopEntries.heuristicLookup(modelData.name)?.icon ?? "";
                    return icon === "" ? "" : Quickshell.iconPath(icon, true);
                }

                width: list.width
                implicitHeight: 60
                image: appIcon
                iconBox: 28
                icon: modelData.user === "root" ? "settings" : "terminal"
                first: index === 0
                last: index === root.rows.length - 1
                active: root.selectedKey === modelData.key
                title: modelData.name + (modelData.count > 1 ? "  (" + modelData.count + ")" : "")
                subtitle: Processes.onlyMine ? modelData.detail : modelData.user + "  ·  " + modelData.detail
                // the three columns sit over the row's right side
                trailingSpace: columns.implicitWidth
                // clicking the chosen row again lets go of it
                onClicked: root.selectedKey = root.selectedKey === modelData.key ? "" : modelData.key

                Row {
                    id: columns

                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    StyledText {
                        width: 80
                        text: root.formatCpu(row.modelData.cpu)
                        color: row.active ? row.contentColor : (row.busy ? root.hot : Appearance.fgColor)
                        font.features: {
                            "tnum": 1
                        }
                    }

                    StyledText {
                        width: 100
                        text: root.formatBytes(row.modelData.mem)
                        color: row.contentColor
                        font.features: {
                            "tnum": 1
                        }
                    }

                    StyledText {
                        width: 80
                        text: row.modelData.pid
                        color: row.contentColor
                        opacity: 0.65
                        font.features: {
                            "tnum": 1
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            text: Processes.status !== "" ? Processes.status : (root.rows.length + (Processes.grouped ? " programs" : " processes") + (root.selectedRow ? "  ·  " + root.selectedRow.name + " selected  ·  Delete ends it" : "  ·  Click one to select it"))
            color: Appearance.mutedColor
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
