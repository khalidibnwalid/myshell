import "../../components/"
import "../../config/"
import "../../services" as Services
import "."
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Item {
    id: root

    property var barWindow
    // the screen this bar is on
    property string screenName: ""

    // With separate workspaces per screen, this bar shows only its screen's own set (a screen that
    // is unplugged hands its set to the first screen that is left), and the pill marks the screen's
    // own active workspace: filled when this screen has the focus, an outline when the other one has.
    readonly property bool split: Services.HyprSettings.workspaceSplit && Services.HyprSettings.barOwnWorkspaces && Services.HyprSettings.workspaceScreens.indexOf(screenName) >= 0
    readonly property var connected: Hyprland.monitors.values.map(m => m.name)
    readonly property var owned: {
        if (!split)
            return [];
        const screens = Services.HyprSettings.workspaceScreens;
        const n = Services.HyprSettings.workspaceCount;
        const out = [];
        for (let k = 0; k < screens.length; k++) {
            const mine = screens[k] === screenName;
            // the set of a screen that is not connected goes to the first connected screen of the list
            const orphan = connected.indexOf(screens[k]) < 0 && screenName === screens.find(x => connected.indexOf(x) >= 0);
            if (mine || orphan)
                for (let i = 1; i <= n; i++)
                    out.push(k * n + i);
        }
        // workspaces past the pinned sets (11, 12, ...) show on the screen that has them now
        const pinned = screens.length * n;
        const extra = Hyprland.workspaces.values.filter(w => w.id > pinned && w.monitor?.name === screenName).map(w => w.id);
        extra.sort((a, b) => a - b);
        const result = out.concat(extra);
        // a spare hollow dot for the next new workspace, on the screen that has the focus (a new
        // workspace opens there)
        if (screenFocused)
            result.push(Hyprland.workspaces.values.reduce((max, w) => Math.max(max, w.id), pinned) + 1);
        return result;
    }
    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screenName) ?? null
    readonly property bool screenFocused: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === screenName : true

    // total number of workspaces = highest id (+1 spare)
    property int _numberOfWS: Hyprland.workspaces.values.length > 0 ? Hyprland.workspaces.values[Hyprland.workspaces.values.length - 1].id : 0

    readonly property bool horizontal: Config.barHorizontal

    implicitWidth: column.implicitWidth + (horizontal ? 12 : 0)
    implicitHeight: column.implicitHeight

    // top and bottom bars: the workspaces sit in a capsule like the clock
    Rectangle {
        anchors.centerIn: parent
        width: column.implicitWidth + 12
        height: 36
        radius: 18
        visible: root.horizontal
        color: Appearance.surfaceColor
    }

    // one line of workspaces along the bar
    GridLayout {
        id: column

        anchors.centerIn: parent
        columns: root.horizontal ? -1 : 1
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: root.split ? root.owned.length : root._numberOfWS + 1

            delegate: Item {
                id: ws

                required property int index
                property int workspaceId: root.split ? root.owned[index] : index + 1
                property HyprlandWorkspace currentWs: Hyprland.workspaces.values.find(w => w.id === workspaceId) || null
                // the workspace showing on this bar's screen (the one that has the focus, when split is off)
                property bool active: root.split ? (root.monitor?.activeWorkspace?.id === workspaceId) : (currentWs?.focused ?? false)
                property bool focused: active
                property bool occupied: (currentWs?.toplevels?.values?.length ?? 0) > 0

                // length along the bar: the focused workspace is a longer pill
                property real extent: focused ? 52 : 24

                implicitWidth: root.horizontal ? extent : 36
                implicitHeight: root.horizontal ? 36 : extent

                Behavior on extent {
                    NumberAnimation {
                        duration: Appearance.animNormal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.easeOut
                    }
                }

                // active workspace pill
                Rectangle {
                    anchors.centerIn: parent
                    width: root.horizontal ? parent.width - 4 : 28
                    height: root.horizontal ? 26 : parent.height - 4
                    radius: 14
                    // the other screen has the focus: an outline instead of a filled pill
                    readonly property bool dimmed: root.split && !root.screenFocused
                    color: dimmed ? "transparent" : Appearance.accentColor
                    border.width: dimmed ? 2 : 0
                    border.color: Appearance.accentColor
                    opacity: ws.focused ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: ws.workspaceId
                        color: parent.dimmed ? Appearance.accentColor : Appearance.accentContrastColor
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                }

                // dot: filled = has windows, hollow = empty
                Rectangle {
                    anchors.centerIn: parent
                    width: 9
                    height: 9
                    radius: 4.5
                    visible: !ws.focused
                    color: ws.occupied ? Appearance.fgColor : "transparent"
                    border.width: ws.occupied ? 0 : 1.5
                    border.color: Appearance.mutedColor
                    scale: wsArea.containsMouse ? 1.35 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: wsArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.HyprCommand.goToWorkspace(ws.workspaceId)
                    // hovering a workspace with windows lists them next to the bar
                    onEntered: {
                        if (ws.occupied)
                            popup.show(ws.currentWs, ws.mapToItem(null, ws.width / 2, ws.height / 2));
                        else
                            popup.hideLater();
                    }
                    onExited: popup.hideLater()
                }
            }
        }
    }

    WorkspacePopup {
        id: popup

        barWindow: root.barWindow
    }
}
