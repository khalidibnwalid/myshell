pragma ComponentBehavior: Bound

import "../../config/"
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

    LazyLoader {
        id: lazyloader
        active: false

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: root

                required property var modelData
                property real scale: 0.1
                implicitWidth: contentGrid.implicitWidth + 16
                implicitHeight: contentGrid.implicitHeight + 16
                WlrLayershell.layer: WlrLayer.Overlay
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.bgColor
                    opacity: 0.5
                    radius: 16
                    border.color: Appearance.accentColor
                    border.width: 2
                }

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
                    
                    color: Appearance.accentColor
                    opacity: 0.2
                    radius: 8
                    border.color: Appearance.accentColor
                    border.width: 2
                    z: 5 // Below dragged item but above grid backgrounds

                    Text {
                        text: globalDropArea.ghostWorkspaceId
                        anchors.centerIn: parent
                        color: Appearance.fgColor
                        opacity: 0.5
                        font.pixelSize: 32
                    }
                }

                GridLayout {
                    id: contentGrid
                    rows: 2
                    columns: 5
                    rowSpacing: 12
                    columnSpacing: 12
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

                            color: "transparent"
                            radius: 8

                            // Ensure source of drag is always on top of other workspaces
                            z: (workspace && globalDropArea.draggingSourceWs === workspace.id) ? 200 : 0

                            // Base background
                            Rectangle {
                                anchors.fill: parent
                                color: Appearance.accentColor
                                opacity: workspace?.focused ? 0.3 : 0
                                radius: 8
                                border.color: workspace?.focused ? Appearance.accentColor : "transparent"
                                border.width: 2
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }

                            // Drag highlight
                            Rectangle {
                                anchors.fill: parent
                                color: Appearance.accentColor
                                opacity: workspaceContainer.containsDrag ? 0.4 : 0
                                radius: 8
                                border.color: Appearance.accentColor
                                border.width: 3
                                scale: workspaceContainer.containsDrag ? 1.05 : 1.0

                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            }

                            // Drop Placeholder
                            Rectangle {
                                id: placeholder
                                visible: workspaceContainer.containsDrag && globalDropArea.draggingSource
                                property var src: globalDropArea.draggingSource

                                width: src ? src.width : 0
                                height: src ? src.height : 0
                                x: src ? (src.toplevelData.at[0] * root.scale * monitor.scale) : 0
                                y: src ? (src.toplevelData.at[1] * root.scale * monitor.scale) : 0

                                color: Appearance.accentColor
                                opacity: 0.4
                                radius: 4
                                border.color: Appearance.accentColor
                                border.width: 2
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
                                onClicked: Hyprland.dispatch(`workspace ${workspaceContainer.workspaceId}`)
                            }

                            // toplevels
                            Repeater {
                                model: workspaceContainer.workspace?.toplevels

                                delegate: Item {
                                    id: toplevelWrapper

                                    required property HyprlandToplevel modelData
                                    property Toplevel waylandHandle: modelData?.wayland
                                    property var toplevelData: modelData.lastIpcObject

                                    width: (toplevelData.size[0] / monitor.width) * workspaceContainer.width * monitor.scale
                                    height: (toplevelData.size[1] / monitor.height) * workspaceContainer.height * monitor.scale

                                    x: (toplevelData.at[0]) * root.scale * monitor.scale
                                    y: (toplevelData.at[1]) * root.scale * monitor.scale
                                    z: dragArea.drag.active ? 100 : ((waylandHandle.fullscreen || waylandHandle.maximized) ? 2 : toplevelData.floating)
                                    scale: dragArea.drag.active ? 1.1 : 1.0
                                    opacity: dragArea.drag.active ? 0.8 : 1.0

                                    // Move Drag properties to the wrapper itself
                                    Drag.active: dragArea.drag.active
                                    Drag.source: toplevelWrapper
                                    Drag.keys: ["toplevel"]
                                    Drag.hotSpot.x: width / 2
                                    Drag.hotSpot.y: height / 2

                                    Behavior on scale { NumberAnimation { id: dropAnim; duration: 250; easing.type: Easing.OutBack } }
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    ScreencopyView {
                                        id: toplevel
                                        anchors.fill: parent
                                        captureSource: toplevelWrapper.waylandHandle
                                        live: true

                                        IconImage {
                                            source: Quickshell.iconPath(DesktopEntries.heuristicLookup(toplevelWrapper.toplevelData?.class)?.icon, "image-missing")
                                            implicitSize: 48
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
                                                toplevelWrapper.x = Qt.binding(() => (toplevelWrapper.toplevelData.at[0]) * root.scale * monitor.scale);
                                                toplevelWrapper.y = Qt.binding(() => (toplevelWrapper.toplevelData.at[1]) * root.scale * monitor.scale);
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

                            Text {
                                text: workspaceContainer.workspaceId
                                color: Appearance.fgColor
                                font.pixelSize: 28
                                font.weight: Font.DemiBold
                                x: 14
                                z: 4
                                opacity: 0.7
                                anchors.bottom: parent.bottom
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
                            Hyprland.dispatch(`movetoworkspacesilent ${targetWs},address:${address}`);
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
