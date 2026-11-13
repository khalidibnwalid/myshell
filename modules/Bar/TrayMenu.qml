import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Context menu of a tray item, shown beside the bar at the icon's height.
PanelWindow {
    id: root

    property var item: null // SystemTrayItem
    property var barWindow
    property real anchorY: 0
    property bool open: false
    readonly property bool barRight: Config.layout.barPosition === "right"
    readonly property real maxHeight: (screen ? screen.height : 800) - 20

    function show(trayItem, y) {
        item = trayItem;
        anchorY = y;
        open = true;
    }

    visible: open && item !== null
    anchors.top: true
    anchors.right: barRight
    anchors.left: !barRight
    // level with the icon, but never past the bottom of the screen
    margins.top: Math.max(10, Math.min(anchorY - 14, maxHeight + 10 - implicitHeight))
    margins.right: 8
    margins.left: 8
    exclusiveZone: 0
    implicitWidth: 248
    implicitHeight: Math.min(maxHeight, content.implicitHeight + 16)
    color: "transparent"

    // click anywhere else to dismiss
    HyprlandFocusGrab {
        windows: [root, root.barWindow]
        active: root.visible
        onCleared: root.open = false
    }

    Rectangle {
        anchors.fill: parent
        // outer radius = entry radius (12) + padding (8)
        radius: 20
        color: Appearance.panelColor
        border.width: 1
        border.color: Appearance.hairlineColor
        clip: true
        // quick fade in once mapped; closing is immediate
        opacity: root.visible && root.backingWindowVisible ? 1 : 0

        Behavior on opacity {
            enabled: root.visible

            NumberAnimation {
                duration: 90
            }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 8
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: content

                width: parent.width
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.topMargin: 6
                    Layout.bottomMargin: 2
                    visible: text !== ""
                    text: root.item ? (root.item.tooltipTitle || root.item.title || "") : ""
                    elide: Text.ElideRight
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                TrayMenuList {
                    Layout.fillWidth: true
                    menu: root.item ? root.item.menu : null
                    onCloseRequested: root.open = false
                }
            }
        }
    }
}
