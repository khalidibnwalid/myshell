pragma ComponentBehavior: Bound

import "../../components/"
import "../../config/"
import "../../services" as Services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Bottom dock: pinned apps, then the other running apps.
// It shows on an empty workspace and when the pointer touches the bottom edge of the screen.
// Hover an icon for its windows, right-click for the menu, drag to reorder or pin.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            // tile (60) + gap (6); outer radius = tile radius (20) + padding (10)
            readonly property int cell: 66
            readonly property int tile: 60
            readonly property int iconSize: 44
            readonly property int padding: 10
            readonly property int dockHeight: tile + 2 * padding
            readonly property int dockMargin: 12
            readonly property int separator: 15

            readonly property HyprlandMonitor monitor: Hyprland.monitors.values.find(m => m.name === modelData.name) ?? null
            // "home": nothing open on the workspace in front
            readonly property bool homeEmpty: (monitor?.activeWorkspace?.toplevels?.values?.length ?? 0) === 0
            readonly property bool hasItems: Services.DockApps.order.length > 0
            // set a moment after the pointer arrives, cleared a moment after it leaves
            property bool pointerReveal: false
            // the window was told the pointer left; see cursorCheck
            property bool pointerLost: true
            // pointer position in the window, for the magnification; far away when outside
            property real pointerX: -10000
            property real pointerY: -10000
            readonly property bool pointerOnDock: pointerY >= dock.y - 6 && dragId === ""
            readonly property bool revealed: hasItems && (homeEmpty || pointerReveal || menuId !== "" || dragId !== "")

            // app under the pointer whose windows are shown, and app whose menu is open
            property string previewId: ""
            property string menuId: ""
            readonly property string cardId: menuId !== "" ? menuId : previewId

            // drag state: the icon being moved and the order shown while it moves
            property string dragId: ""
            property var dragOrder: []
            readonly property var displayOrder: dragId !== "" ? dragOrder : Services.DockApps.order
            // pinned icons sit left of the separator; a running app dragged in among them counts already
            readonly property int displayPinned: {
                const pinned = Services.DockApps.pinnedCount;
                if (dragId !== "" && !Services.DockApps.isPinned(dragId) && dragOrder.indexOf(dragId) < pinned)
                    return pinned + 1;
                return pinned;
            }
            readonly property bool showSeparator: displayPinned > 0 && displayPinned < displayOrder.length

            function slotX(slot) {
                return slot * cell + (showSeparator && slot >= displayPinned ? separator : 0);
            }

            function closeCards() {
                previewId = "";
                menuId = "";
            }

            screen: modelData
            visible: hasItems && Config.dock.enabled
            color: "transparent"
            exclusiveZone: 0
            implicitHeight: 360
            onRevealedChanged: {
                if (!revealed)
                    closeCards();
            }

            anchors {
                bottom: true
                left: true
                right: true
            }

            // input: the bottom edge always, the dock and its card only while they show
            mask: Region {
                item: edgeStrip

                Region {
                    item: win.revealed ? dockHit : null
                }

                Region {
                    item: card.visible ? cardHit : null
                }
            }

            // click anywhere else to close the menu
            HyprlandFocusGrab {
                windows: [win]
                active: win.menuId !== ""
                onCleared: win.menuId = ""
            }

            Timer {
                id: revealTimer

                interval: 90
                onTriggered: win.pointerReveal = true
            }

            Timer {
                id: hideTimer

                interval: 320
                onTriggered: cursorCheck.running = true
            }

            // The compositor also reports "pointer left" when the dock's input area changes
            // under a pointer that is not moving (the dock sliding in, a card opening).
            // So before hiding, ask where the pointer really is.
            Process {
                id: cursorCheck

                command: ["hyprctl", "cursorpos"]

                stdout: StdioCollector {
                    onStreamFinished: {
                        const m = this.text.match(/(-?\d+),\s*(-?\d+)/);
                        if (!m || !win.pointerLost) {
                            return;
                        }
                        // pointer in window coordinates; the window sits at the bottom of the screen
                        // the window is pushed aside by a left bar and sits above a bottom bar
                        const barLeft = Config.barPosition === "left";
                        const barBottom = Config.barPosition === "bottom";
                        const x = parseInt(m[1]) - win.modelData.x - (barLeft ? win.modelData.width - win.width : 0);
                        const y = parseInt(m[2]) - win.modelData.y - (win.modelData.height - win.height - (barBottom ? Config.barSize : 0));
                        const inside = item => x >= item.x && x <= item.x + item.width && y >= item.y && y <= item.y + item.height;
                        if (win.pointerReveal && (inside(dockHit) || (card.visible && inside(cardHit))))
                            hideTimer.restart();
                        else
                            win.pointerReveal = false;
                    }
                }
            }

            Timer {
                id: previewTimer

                property string target: ""

                interval: 160
                onTriggered: {
                    if (win.menuId === "" && win.dragId === "")
                        win.previewId = target;
                }
            }

            Item {
                anchors.fill: parent

                // the pointer only reaches the window inside the mask
                HoverHandler {
                    onPointChanged: {
                        win.pointerX = point.position.x;
                        win.pointerY = point.position.y;
                    }
                    onHoveredChanged: {
                        win.pointerLost = !hovered;
                        if (!hovered) {
                            win.pointerX = -10000;
                            win.pointerY = -10000;
                        }
                        if (hovered) {
                            hideTimer.stop();
                            if (!win.pointerReveal)
                                revealTimer.restart();
                        } else {
                            revealTimer.stop();
                            previewTimer.stop();
                            hideTimer.restart();
                        }
                    }
                }
            }

            Item {
                id: edgeStrip

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
            }

            // the dock and the strip below it, so the pointer can travel from the edge onto it
            Item {
                id: dockHit

                x: dock.x - 10
                y: dock.y - 8
                width: dock.width + 20
                height: win.height - y
            }

            // the card and the gap between it and the dock
            Item {
                id: cardHit

                x: card.x
                y: card.y
                width: card.width
                height: dock.y - card.y
            }

            // --- dock ---
            Rectangle {
                id: dock

                anchors.horizontalCenter: parent.horizontalCenter
                y: win.height - win.dockHeight - win.dockMargin
                width: strip.width + 2 * win.padding - (win.cell - win.tile)
                height: win.dockHeight
                radius: 20 + win.padding
                color: Appearance.panelColor
                border.width: 1
                border.color: Appearance.hairlineColor
                opacity: win.revealed ? 1 : 0

                // soft light from the top edge, like the glass it sits on
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.alpha(Appearance.fgColor, 0.07)
                        }

                        GradientStop {
                            position: 0.55
                            color: "transparent"
                        }
                    }
                }

                transform: Translate {
                    y: win.revealed ? 0 : win.dockHeight + win.dockMargin + 6

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

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.animNormal
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: strip

                    x: win.padding - (win.cell - win.tile) / 2
                    width: win.displayOrder.length * win.cell + (win.showSeparator ? win.separator : 0)
                    height: parent.height

                    Rectangle {
                        visible: win.showSeparator
                        x: win.displayPinned * win.cell + (win.separator - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 30
                        color: Appearance.hairlineColor

                        Behavior on x {
                            NumberAnimation {
                                duration: Appearance.animNormal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Repeater {
                        // ids only, so an icon keeps its item while the order changes around it
                        model: ScriptModel {
                            values: Services.DockApps.order
                        }

                        delegate: Item {
                            id: icon

                            required property string modelData
                            readonly property var app: Services.DockApps.apps[modelData] ?? null
                            readonly property int windowCount: app?.windows?.length ?? 0
                            readonly property bool appFocused: (app?.windows ?? []).some(w => w.activated)
                            readonly property bool dragging: win.dragId === modelData
                            readonly property int slot: Math.max(0, win.displayOrder.indexOf(modelData))
                            property real dragX: 0
                            // 1 under the pointer, easing to 0 about two icons away
                            readonly property real nearness: {
                                if (!win.pointerOnDock)
                                    return 0;
                                const centre = dock.x + strip.x + x + win.cell / 2;
                                const t = Math.max(0, 1 - Math.abs(win.pointerX - centre) / (win.cell * 1.9));
                                return t * t * (3 - 2 * t);
                            }

                            x: dragging ? dragX : win.slotX(slot)
                            z: dragging ? 10 : 0
                            width: win.cell
                            height: strip.height

                            Behavior on x {
                                enabled: !icon.dragging

                                NumberAnimation {
                                    duration: Appearance.animNormal
                                    easing.type: Easing.OutCubic
                                }
                            }

                            HoverHandler {
                                id: iconHover

                                onHoveredChanged: {
                                    if (!hovered)
                                        return;
                                    previewTimer.target = icon.modelData;
                                    // once a card is showing, moving along the dock switches at once
                                    if (win.previewId !== "" && win.menuId === "" && win.dragId === "")
                                        win.previewId = icon.modelData;
                                    else
                                        previewTimer.restart();
                                }
                            }

                            // tile: surface on hover, accent tint for the app that has the focus
                            Rectangle {
                                id: tileBg

                                readonly property bool hot: (iconHover.hovered || win.cardId === icon.modelData) && !icon.dragging

                                anchors.centerIn: parent
                                width: win.tile
                                height: win.tile
                                radius: 20
                                color: icon.appFocused ? Qt.alpha(Appearance.accentColor, hot ? 0.26 : 0.18) : (hot ? Appearance.surfaceHighColor : "transparent")
                                border.width: icon.appFocused ? 1.5 : 0
                                border.color: Qt.alpha(Appearance.accentColor, 0.5)
                                opacity: icon.dragging ? 0 : 1

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.animFast
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Appearance.animFast
                                    }
                                }
                            }

                            Image {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: icon.windowCount > 0 ? -3 : 0
                                width: win.iconSize
                                height: win.iconSize
                                source: icon.app?.icon ?? ""
                                sourceSize: Qt.size(win.iconSize * 2, win.iconSize * 2)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                scale: icon.dragging ? 1.14 : (iconArea.pressed ? 0.92 : 1 + 0.24 * icon.nearness)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 110
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on anchors.verticalCenterOffset {
                                    NumberAnimation {
                                        duration: Appearance.animFast
                                    }
                                }
                            }

                            // running: a small dot inside the tile, an accent bar when focused
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: tileBg.bottom
                                anchors.bottomMargin: 4
                                width: icon.appFocused ? 16 : 4
                                height: 4
                                radius: 2
                                color: icon.appFocused ? Appearance.accentColor : Appearance.mutedColor
                                opacity: icon.windowCount > 0 && !icon.dragging ? 1 : 0

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Appearance.animNormal
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Appearance.animFast
                                    }
                                }
                            }

                            MouseArea {
                                id: iconArea

                                property real pressX: 0

                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onPressed: mouse => pressX = mapToItem(strip, mouse.x, mouse.y).x
                                onPositionChanged: mouse => {
                                    if (!(pressedButtons & Qt.LeftButton))
                                        return;
                                    const x = mapToItem(strip, mouse.x, mouse.y).x;
                                    if (!icon.dragging) {
                                        if (Math.abs(x - pressX) < 10)
                                            return;
                                        // start dragging
                                        win.closeCards();
                                        win.dragOrder = Services.DockApps.order.slice();
                                        icon.dragX = icon.x;
                                        win.dragId = icon.modelData;
                                    }
                                    icon.dragX = Math.max(-win.cell / 2, Math.min(strip.width - win.cell / 2, x - win.cell / 2));
                                    // slot under the icon's centre; a pinned app stays among the pins
                                    const pinned = Services.DockApps.isPinned(icon.modelData);
                                    const last = pinned ? Services.DockApps.pinnedCount - 1 : win.dragOrder.length - 1;
                                    const target = Math.max(0, Math.min(last, Math.floor((icon.dragX + win.cell / 2) / win.cell)));
                                    const current = win.dragOrder.indexOf(icon.modelData);
                                    if (target !== current) {
                                        const next = win.dragOrder.slice();
                                        next.splice(current, 1);
                                        next.splice(target, 0, icon.modelData);
                                        win.dragOrder = next;
                                    }
                                }
                                onReleased: mouse => {
                                    if (icon.dragging) {
                                        const index = win.dragOrder.indexOf(icon.modelData);
                                        const id = icon.modelData;
                                        // dropping among the pins reorders, or pins a running app there
                                        if (index < win.displayPinned)
                                            Services.DockApps.pin(id, index);
                                        win.dragId = "";
                                        return;
                                    }
                                    if (!containsMouse)
                                        return;
                                    if (mouse.button === Qt.RightButton) {
                                        win.previewId = "";
                                        win.menuId = win.menuId === icon.modelData ? "" : icon.modelData;
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        Services.DockApps.launch(icon.modelData);
                                    } else {
                                        win.closeCards();
                                        Services.DockApps.activate(icon.modelData);
                                    }
                                }
                                onCanceled: win.dragId = ""
                            }
                        }
                    }
                }
            }

            // --- card above the hovered icon: its windows, or its menu ---
            Rectangle {
                id: card

                readonly property var app: Services.DockApps.apps[win.cardId] ?? null
                readonly property real iconCentre: dock.x + strip.x + win.slotX(Math.max(0, win.displayOrder.indexOf(win.cardId))) + win.cell / 2

                visible: win.revealed && win.cardId !== "" && app !== null && win.dragId === ""
                x: Math.max(8, Math.min(win.width - width - 8, iconCentre - width / 2))
                y: dock.y - 10 - height
                width: cardLoader.implicitWidth + 20
                height: cardLoader.implicitHeight + 20
                // outer radius = inner radius (14) + padding (10)
                radius: 24
                color: Appearance.panelColor
                border.width: 1
                border.color: Appearance.hairlineColor

                Loader {
                    id: cardLoader

                    anchors.centerIn: parent
                    active: card.visible
                    sourceComponent: win.menuId !== "" ? menuComponent : previewComponent
                }
            }

            // windows of the app, live; just the name when it is not running
            Component {
                id: previewComponent

                RowLayout {
                    spacing: 6

                    StyledText {
                        visible: (card.app?.windows?.length ?? 0) === 0
                        Layout.margins: 2
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        text: card.app?.name ?? ""
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Repeater {
                        model: (card.app?.windows ?? []).slice(0, 5)

                        delegate: Rectangle {
                            id: thumb

                            required property var modelData
                            readonly property var size: modelData.lastIpcObject?.size ?? [16, 10]
                            readonly property real previewHeight: 118
                            readonly property real previewWidth: Math.max(110, Math.min(230, previewHeight * size[0] / Math.max(1, size[1])))

                            implicitWidth: previewWidth + 12
                            implicitHeight: previewHeight + 36
                            radius: 14
                            color: thumbHover.hovered ? Appearance.surfaceHighColor : "transparent"

                            HoverHandler {
                                id: thumbHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Services.DockApps.focusWindow(thumb.modelData);
                                    win.closeCards();
                                }
                            }

                            ClippingRectangle {
                                x: 6
                                y: 6
                                width: thumb.previewWidth
                                height: thumb.previewHeight
                                radius: 8
                                color: Appearance.surfaceColor

                                ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: thumb.modelData.wayland
                                    live: true
                                }
                            }

                            StyledText {
                                x: 8
                                y: thumb.previewHeight + 11
                                width: thumb.previewWidth - 4
                                text: thumb.modelData.title || card.app?.name || ""
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                font.pixelSize: 12
                            }

                            Rectangle {
                                x: thumb.width - width - 10
                                y: 10
                                width: 24
                                height: 24
                                radius: 12
                                visible: thumbHover.hovered
                                color: Qt.alpha(Appearance.bgColor, 0.8)

                                IconButton {
                                    anchors.fill: parent
                                    size: 24
                                    iconSize: 15
                                    icon: "close"
                                    onClicked: {
                                        if (thumb.modelData.wayland)
                                            thumb.modelData.wayland.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: menuComponent

                ColumnLayout {
                    id: menu

                    readonly property string appId: win.menuId
                    readonly property int windowCount: card.app?.windows?.length ?? 0

                    spacing: 2

                    component MenuRow: Rectangle {
                        id: row

                        property string icon
                        property string text

                        signal clicked()

                        Layout.fillWidth: true
                        implicitWidth: rowLayout.implicitWidth + 28
                        implicitHeight: 36
                        radius: 14
                        color: rowArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

                        RowLayout {
                            id: rowLayout

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 18
                            spacing: 10

                            MaterialSymbol {
                                icon: row.icon
                                font.pixelSize: 18
                                color: Appearance.fgColor
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.text
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                row.clicked();
                                win.menuId = "";
                            }
                        }
                    }

                    StyledText {
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: 2
                        Layout.bottomMargin: 4
                        text: card.app?.name ?? ""
                        color: Appearance.mutedColor
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    MenuRow {
                        visible: !!card.app?.entry
                        icon: menu.windowCount > 0 ? "open_in_new" : "play_arrow"
                        text: menu.windowCount > 0 ? "New window" : "Open"
                        onClicked: Services.DockApps.launch(menu.appId)
                    }

                    MenuRow {
                        // only apps with a desktop entry can be started again from the dock
                        visible: !!card.app?.entry
                        icon: "keep"
                        text: card.app?.pinned ? "Unpin from dock" : "Pin to dock"
                        onClicked: card.app?.pinned ? Services.DockApps.unpin(menu.appId) : Services.DockApps.pin(menu.appId)
                    }

                    MenuRow {
                        visible: menu.windowCount > 0
                        icon: "close"
                        text: menu.windowCount > 1 ? "Close all windows" : "Close window"
                        onClicked: Services.DockApps.closeAll(menu.appId)
                    }
                }
            }
        }
    }
}
