pragma ComponentBehavior: Bound

import "../../components/"
import "../../components/WorkspaceShapes.js" as Shapes
import "../../config/"
import "../../services" as Services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

Scope {
    GlobalShortcut {
        name: "workspaces"
        onPressed: lazyloader.active = !lazyloader.active
    }

    Connections {
        target: Hyprland

        function onRawEvent() {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    // click anywhere else to dismiss
    HyprlandFocusGrab {
        windows: lazyloader.item ? [...lazyloader.item.instances] : []
        active: lazyloader.active && windows.length > 0
        onCleared: lazyloader.active = false
    }

    LazyLoader {
        id: lazyloader
        active: false

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: root

                required property var modelData
                property real scale: 0.1
                // outer radius = cell radius + padding
                readonly property int cellRadius: 14
                readonly property int padding: 12

                implicitWidth: contentGrid.implicitWidth + padding * 2
                implicitHeight: contentGrid.implicitHeight + padding * 2
                WlrLayershell.layer: WlrLayer.Overlay
                // its own name, so Hyprland can pop this window in and out (see windowrules.conf)
                WlrLayershell.namespace: "quickshell-workspaces"
                color: "transparent"

                Rectangle {
                    id: background

                    anchors.fill: parent
                    color: Appearance.panelColor
                    radius: root.cellRadius + root.padding
                    border.color: Appearance.hairlineColor
                    border.width: 1
                }

                // No fade of its own: Hyprland pops the window in (the "popin" layer rule) together with
                // the blur behind it. A fade here on top left the blur showing alone for the first frames.

                // Ghost placeholder for new workspaces
                Rectangle {
                    id: ghostCell
                    visible: globalDropArea.ghostWorkspaceId > 0
                    
                    // Calculate position relative to contentGrid
                    x: contentGrid.x + (((globalDropArea.ghostWorkspaceId - 1) % 5) * (width + contentGrid.columnSpacing))
                    y: contentGrid.y + (Math.floor((globalDropArea.ghostWorkspaceId - 1) / 5) * (height + contentGrid.rowSpacing))
                    
                    property var monitor: Hyprland.monitors.values[0] || { width: 1920, height: 1080, scale: 1 }
                    width: monitor.width * root.scale
                    height: monitor.height * root.scale
                    
                    color: Qt.alpha(Appearance.accentColor, 0.16)
                    radius: root.cellRadius
                    border.color: Qt.alpha(Appearance.accentColor, 0.6)
                    border.width: 1
                    z: 5 // Below dragged item but above grid backgrounds

                    StyledText {
                        text: globalDropArea.ghostWorkspaceId
                        anchors.centerIn: parent
                        color: Appearance.accentColor
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }
                }

                GridLayout {
                    id: contentGrid
                    rows: 2
                    columns: 5
                    rowSpacing: 8
                    columnSpacing: 8
                    anchors.centerIn: parent

                    // workspaces
                    Repeater {
                        model: Hyprland.workspaces.values.length > 0 
                                            ? Hyprland.workspaces.values.reduce((max, w) => Math.max(max, w.id), 0) 
                                            : 0

                        delegate: Rectangle {
                            id: workspaceContainer

                            required property int index
                            property int workspaceId: index + 1
                            property HyprlandWorkspace workspace: Hyprland.workspaces.values.find(w => w.id === workspaceId) ?? null
                            property HyprlandMonitor monitor: Hyprland.monitors.values[0] || { width: 1920, height: 1080, scale: 1 }
                            property bool containsDrag: false

                            width: monitor.width * root.scale
                            height: monitor.height * root.scale

                            color: Appearance.surfaceColor
                            radius: root.cellRadius

                            // Ensure source of drag is always on top of other workspaces
                            z: (workspace && globalDropArea.draggingSourceWs === workspace.id) ? 200 : 0

                            // Base background
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.alpha(Appearance.accentColor, 0.12)
                                opacity: workspace?.focused ? 1 : 0
                                radius: root.cellRadius
                                border.color: Appearance.accentColor
                                border.width: 2
                                z: 3 // the focus ring stays above the window previews
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Appearance.animNormal
                                    }
                                }
                            }

                            // Drag highlight
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.alpha(Appearance.accentColor, 0.3)
                                opacity: workspaceContainer.containsDrag ? 1 : 0
                                radius: root.cellRadius
                                border.color: Appearance.accentColor
                                border.width: 2
                                scale: workspaceContainer.containsDrag ? 1.03 : 1.0

                                Behavior on opacity { NumberAnimation { duration: Appearance.animFast } }
                                Behavior on scale { NumberAnimation { duration: Appearance.animNormal; easing.type: Easing.OutCubic } }
                            }

                            // Drop Placeholder
                            Rectangle {
                                id: placeholder
                                visible: workspaceContainer.containsDrag && globalDropArea.draggingSource
                                property var src: globalDropArea.draggingSource

                                width: src ? src.width : 0
                                height: src ? src.height : 0
                                x: src ? ((src.toplevelData.at[0] - src.screenOf.x) / src.screenW) * workspaceContainer.width : 0
                                y: src ? ((src.toplevelData.at[1] - src.screenOf.y) / src.screenH) * workspaceContainer.height : 0

                                color: Appearance.accentColor
                                opacity: 0.4
                                radius: 8
                                border.color: Appearance.accentColor
                                border.width: 1
                                z: 10

                                SequentialAnimation on opacity {
                                    running: placeholder.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.1; duration: 600; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.HyprCommand.goToWorkspace(workspaceContainer.workspaceId)
                            }

                            // toplevels
                            Repeater {
                                model: workspaceContainer.workspace?.toplevels

                                delegate: Item {
                                    id: toplevelWrapper

                                    required property HyprlandToplevel modelData
                                    property Toplevel waylandHandle: modelData?.wayland
                                    property var toplevelData: modelData.lastIpcObject

                                    // the screen this workspace is on: window positions are relative to it, as a share of its size,
                                    // so a window on the second screen lands in the right place of the same-sized cell
                                    property var screenOf: workspaceContainer.workspace?.monitor ?? workspaceContainer.monitor
                                    property real screenW: screenOf.width / screenOf.scale
                                    property real screenH: screenOf.height / screenOf.scale

                                    width: ((toplevelData?.size?.[0] ?? 0) / screenW) * workspaceContainer.width
                                    height: ((toplevelData?.size?.[1] ?? 0) / screenH) * workspaceContainer.height

                                    x: (((toplevelData?.at?.[0] ?? screenOf.x) - screenOf.x) / screenW) * workspaceContainer.width
                                    y: (((toplevelData?.at?.[1] ?? screenOf.y) - screenOf.y) / screenH) * workspaceContainer.height
                                    z: dragArea.drag.active ? 100 : ((waylandHandle?.fullscreen || waylandHandle?.maximized) ? 2 : (toplevelData?.floating ? 1 : 0))
                                    scale: dragArea.drag.active ? 1.06 : 1.0
                                    opacity: dragArea.drag.active ? 0.85 : 1.0

                                    // Move Drag properties to the wrapper itself
                                    Drag.active: dragArea.drag.active
                                    Drag.source: toplevelWrapper
                                    Drag.keys: ["toplevel"]
                                    Drag.hotSpot.x: width / 2
                                    Drag.hotSpot.y: height / 2

                                    Behavior on scale { NumberAnimation { id: dropAnim; duration: Appearance.animNormal; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    ClippingRectangle {
                                    anchors.fill: parent
                                    radius: Math.min(root.cellRadius, 10)
                                    color: "transparent"

                                    // A live copy stops when the window's buffer changes size (a window dropped beside
                                    // another re-tiles both, and both went blank), and restarting the same view does not
                                    // bring it back: the view is made anew once the size has settled. A window on a hidden
                                    // workspace draws its new size a little later, so it is tried again until there is a picture.
                                    property string sizeKey: toplevelWrapper.toplevelData?.size?.join("x") ?? ""
                                    onSizeKeyChanged: {
                                        recapture.tries = 0;
                                        recapture.restart();
                                    }

                                    Timer {
                                        id: recapture

                                        property int tries: 0

                                        interval: 500
                                        repeat: true
                                        onTriggered: {
                                            if (tries > 0 && copyLoader.item?.hasContent) {
                                                stop();
                                                return;
                                            }
                                            copyLoader.active = false;
                                            copyLoader.active = true;
                                            if (++tries >= 8)
                                                stop();
                                        }
                                    }

                                    Loader {
                                        id: copyLoader

                                        anchors.fill: parent

                                        sourceComponent: ScreencopyView {
                                            captureSource: toplevelWrapper.waylandHandle
                                            live: true
                                        }
                                    }

                                    Item {
                                        id: toplevel
                                        anchors.fill: parent

                                        IconImage {
                                            source: Services.Icons.path(DesktopEntries.heuristicLookup(toplevelWrapper.toplevelData?.class)?.icon ?? "", true)
                                            visible: source != ""
                                            implicitSize: 40
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            id: dragArea
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            anchors.fill: parent

                                            drag.target: toplevelWrapper

                                            onPressed: {
                                                globalDropArea.draggingSource = toplevelWrapper;
                                                globalDropArea.draggingSourceWs = workspaceContainer.workspaceId;
                                            }

                                            onReleased: {
                                                toplevelWrapper.Drag.drop();
                                                // Restore bindings if they were broken by drag
                                                toplevelWrapper.x = Qt.binding(() => ((toplevelWrapper.toplevelData.at[0] - toplevelWrapper.screenOf.x) / toplevelWrapper.screenW) * workspaceContainer.width);
                                                toplevelWrapper.y = Qt.binding(() => ((toplevelWrapper.toplevelData.at[1] - toplevelWrapper.screenOf.y) / toplevelWrapper.screenH) * workspaceContainer.height);
                                            }

                                            onClicked: mouse => {
                                                if (mouse.button === Qt.LeftButton)
                                                    toplevelWrapper.waylandHandle.activate();
                                                else if (mouse.button === Qt.RightButton)
                                                    toplevelWrapper.waylandHandle.close();
                                            }
                                        }
                                    }
                                    }
                                }
                            }

                            // workspace number badge, with the workspace's own shape from the bar when it has one
                            Rectangle {
                                id: badge

                                readonly property string shape: Shapes.shapeOf(Config.bar?.workspaceShapes ?? "", workspaceContainer.workspaceId)
                                readonly property bool hasShape: shape !== "dot" && shape !== ""
                                readonly property color ink: workspaceContainer.workspace?.focused ? Appearance.accentContrastColor : Appearance.fgColor

                                x: 8
                                y: parent.height - height - 8
                                z: 4
                                width: hasShape ? badgeRow.implicitWidth + 14 : 24
                                height: 24
                                radius: 12
                                color: workspaceContainer.workspace?.focused ? Appearance.accentColor : Qt.alpha(Appearance.bgColor, 0.72)

                                Row {
                                    id: badgeRow

                                    anchors.centerIn: parent
                                    spacing: 5

                                    WorkspaceShape {
                                        visible: badge.hasShape
                                        anchors.verticalCenter: parent.verticalCenter
                                        shape: badge.shape
                                        size: 11
                                        fillColor: badge.ink
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: workspaceContainer.workspaceId
                                        color: badge.ink
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }
                    }
                }

                DropArea {
                    id: globalDropArea
                    anchors.fill: parent
                    keys: ["toplevel"]
                    z: 500 // Ensure it's on top of EVERYTHING

                    property var hoveredItem: null
                    property var draggingSource: null
                    property var draggingSourceWs: null
                    property int ghostWorkspaceId: 0

                    onDropped: drop => {
                        const toplevelModel = drop.source.modelData;
                        const address = toplevelModel.lastIpcObject.address;
                        const sourceWsId = toplevelModel.lastIpcObject.workspace.id;

                        let targetWs = 0;
                        const pos = mapToItem(contentGrid, drop.x, drop.y);
                        const item = contentGrid.childAt(pos.x, pos.y);

                        if (item && item.workspaceId !== undefined) {
                            targetWs = item.workspaceId;
                        } else if (ghostWorkspaceId > 0) {
                            targetWs = ghostWorkspaceId;
                        }

                        if (targetWs > 0) {
                            Services.HyprCommand.moveWindowToWorkspace(address, targetWs);
                            Hyprland.refreshWorkspaces();
                            Hyprland.refreshToplevels();
                        } 

                        draggingSource = null;
                        draggingSourceWs = null;
                        hoveredItem = null;
                        ghostWorkspaceId = 0;
                        if (item) item.containsDrag = false;
                    }

                    onPositionChanged: drag => {
                        const pos = mapToItem(contentGrid, drag.x, drag.y);
                        const item = contentGrid.childAt(pos.x, pos.y);
                        
                        // Handle hover for existing items
                        if (item !== hoveredItem) {
                            if (hoveredItem && hoveredItem.workspaceId !== undefined)
                                hoveredItem.containsDrag = false;

                            hoveredItem = item;

                            if (hoveredItem && hoveredItem.workspaceId !== undefined)
                                hoveredItem.containsDrag = true;
                        }

                        // Handle ghost detection for empty spots
                        if (!item) {
                            const monitor = Hyprland.monitors.values[0] || { width: 1920, height: 1080, scale: 1 };
                            const colWidth = (monitor.width * root.scale) + contentGrid.columnSpacing;
                            const rowHeight = (monitor.height * root.scale) + contentGrid.rowSpacing;

                            const col = Math.floor(pos.x / colWidth);
                            const row = Math.floor(pos.y / rowHeight);

                            // Support up to 4 rows (20 workspaces)
                            if (col >= 0 && col < 5 && row >= 0 && row < 4) {
                                ghostWorkspaceId = (row * 5) + col + 1;
                                // Only show ghost if it doesn't exist yet
                                if (Hyprland.workspaces.values.some(w => w.id === ghostWorkspaceId)) {
                                    ghostWorkspaceId = 0;
                                }
                            } else {
                                ghostWorkspaceId = 0;
                            }
                        } else {
                            ghostWorkspaceId = 0;
                        }
                    }

                    onExited: {
                        if (hoveredItem && hoveredItem.hasOwnProperty("containsDrag"))
                            hoveredItem.containsDrag = false;
                        hoveredItem = null;
                        ghostWorkspaceId = 0;
                    }
                }
            }
        }
    }
}
