import "../../config/"
import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: wsIndicatorBar

    property HyprlandWorkspace activeWs: Hyprland.workspaces.values.find(ws => ws.focused)
    property int workspaceCount: Hyprland.workspaces.values.length > 0
        ? Hyprland.workspaces.values[Hyprland.workspaces.values.length - 1].id
        : 1

    width: parent ? parent.width : 48
    height: column.implicitHeight

    Column {
        id: column

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 6

        Repeater {
            model: wsIndicatorBar.workspaceCount

            delegate: Item {
                required property int index

                property int workspaceId: index + 1
                property HyprlandWorkspace currentWs: Hyprland.workspaces.values.find(ws => ws.id === workspaceId) || null
                property list<HyprlandToplevel> workspaceToplevels: currentWs?.toplevels?.values || []

                width: column.width
                height: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    radius: 18
                    color: "#1f1f1f"
                    opacity: currentWs?.focused ? 1 : (workspaceToplevels.length > 0 ? 0.85 : 0)
                }

                Text {
                    anchors.centerIn: parent
                    text: workspaceId
                    color: "#f2f3f1"
                    font.family: "Monospace"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    opacity: currentWs?.focused || workspaceToplevels.length > 0 ? 1 : 0.72
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${workspaceId.toString()}`)
                }
            }
        }
    }
}
