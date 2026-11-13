import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Small pill next to the bar with the app icons of the workspace under the pointer.
PanelWindow {
    id: root

    property var barWindow
    property HyprlandWorkspace workspace: null
    property real anchorY: 0
    property bool open: false
    readonly property bool barRight: Config.layout.barPosition === "right"
    readonly property real screenHeight: screen ? screen.height : 800
    readonly property var windows: workspace?.toplevels?.values ?? []

    function show(ws, y) {
        workspace = ws;
        anchorY = y;
        closeTimer.stop();
        // a short pause, so sweeping over the dots does not flash cards
        if (!open)
            openTimer.restart();
    }

    function hideLater() {
        openTimer.stop();
        closeTimer.restart();
    }

    function iconFor(toplevel) {
        const cls = toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "";
        return Quickshell.iconPath(DesktopEntries.heuristicLookup(cls)?.icon || cls, true);
    }

    screen: barWindow ? barWindow.screen : null
    visible: (open || closeTimer.running) && windows.length > 0
    exclusiveZone: 0
    implicitWidth: card.implicitWidth + 8
    implicitHeight: card.implicitHeight + 8
    color: "transparent"
    Component.onCompleted: WindowManager.registerBarPopup(root)
    Component.onDestruction: WindowManager.unregisterBarPopup(root)

    anchors {
        top: true
        right: barRight
        left: !barRight
    }

    margins {
        top: Math.max(8, Math.min(anchorY - implicitHeight / 2, screenHeight - implicitHeight - 8))
        right: 5
        left: 5
    }

    Timer {
        id: openTimer

        interval: 140
        onTriggered: root.open = true
    }

    Timer {
        id: closeTimer

        interval: 160
        onTriggered: root.open = false
    }

    // a small pill of app icons, one per window; click one to jump to it
    Rectangle {
        id: card

        anchors.fill: parent
        anchors.margins: 4
        implicitWidth: row.implicitWidth + 12
        implicitHeight: 46
        radius: height / 2
        color: Appearance.panelColor
        border.width: 1
        border.color: Appearance.hairlineColor
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.94
        transformOrigin: root.barRight ? Item.Right : Item.Left

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animFast
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animFast
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    closeTimer.stop();
                else
                    root.hideLater();
            }
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: root.windows.slice(0, 8)

                delegate: Rectangle {
                    id: cell

                    required property var modelData

                    width: 34
                    height: 34
                    radius: 17
                    color: cellArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

                    Image {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: root.iconFor(cell.modelData)
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        scale: cellArea.containsMouse ? 1.12 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: cellArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Hyprland.dispatch("focuswindow address:0x" + cell.modelData.address);
                            root.open = false;
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }
            }
        }
    }
}
