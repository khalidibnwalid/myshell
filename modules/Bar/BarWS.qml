import "../../components/"
import "../../components/WorkspaceShapes.js" as Shapes
import "../../config/"
import "../../services" as Services
import "."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    property var barWindow
    // the screen this bar is on
    property string screenName: ""

    // With only one screen connected there is nothing to separate: the bar lists the workspaces in a row,
    // 1, 2, 3 ... up to the highest one (and a spare), as it does without the split.
    // With separate workspaces per screen, this bar shows only its screen's own set (a screen that
    // is unplugged hands its workspaces in use to the first screen that is left), and the pill marks the screen's
    // own active workspace: filled when this screen has the focus, an outline when the other one has.
    readonly property bool split: Services.HyprSettings.workspaceSplit && Services.HyprSettings.barOwnWorkspaces && Services.HyprSettings.workspaceScreens.indexOf(screenName) >= 0 && connected.length > 1
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
            // an unplugged screen's set shows only the workspaces that are in use, not five empty dots
            if (mine || orphan)
                for (let i = 1; i <= n; i++) {
                    const id = k * n + i;
                    if (mine || Hyprland.workspaces.values.some(w => w.id === id))
                        out.push(id);
                }
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
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.easeFade
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

                // marker: filled = has windows, hollow = empty; its shape is set in Settings
                WorkspaceShape {
                    anchors.centerIn: parent
                    shape: Shapes.shapeOf(Config.bar.workspaceShapes, ws.workspaceId)
                    size: shape === "dot" ? 9 : 12
                    visible: !ws.focused
                    filled: ws.occupied
                    scale: wsArea.containsMouse || fileDrop.containsDrag ? 1.35 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.easeStandard
                        }
                    }
                }

                // a ring while files are dragged over the workspace
                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: Qt.alpha(Appearance.accentColor, 0.18)
                    border.width: 2
                    border.color: Appearance.accentColor
                    visible: fileDrop.containsDrag
                }

                // drop files (from a file manager or the desktop) on a workspace to open them there:
                // the workspace is shown first, so the apps start on it
                DropArea {
                    id: fileDrop

                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onDropped: drop => {
                        const urls = drop.urls.map(u => u.toString()).filter(u => u !== "");
                        if (urls.length === 0)
                            return;
                        Services.HyprCommand.goToWorkspace(ws.workspaceId);
                        drop.acceptProposedAction();
                        // a moment for the switch, then each file opens with its default app
                        Quickshell.execDetached(["sh", "-c", "sleep 0.25; for u; do xdg-open \"$u\" >/dev/null 2>&1 & done", "sh"].concat(urls));
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
