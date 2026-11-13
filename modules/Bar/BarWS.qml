import "../../components/"
import "../../config/"
import "."
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Item {
    id: root

    property var barWindow

    // total number of workspaces = highest id (+1 spare)
    property int _numberOfWS: Hyprland.workspaces.values.length > 0 ? Hyprland.workspaces.values[Hyprland.workspaces.values.length - 1].id : 0

    implicitWidth: 40
    implicitHeight: column.implicitHeight

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutQuad
        }
    }

    Column {
        id: column

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Repeater {
            model: root._numberOfWS + 1

            delegate: Item {
                id: ws

                required property int index
                property int workspaceId: index + 1
                property HyprlandWorkspace currentWs: Hyprland.workspaces.values.find(w => w.id === workspaceId) || null
                property bool focused: currentWs?.focused ?? false
                property bool occupied: (currentWs?.toplevels?.values?.length ?? 0) > 0

                width: 40
                height: focused ? 52 : 24

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.animNormal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.easeOut
                    }
                }

                // active workspace pill
                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: parent.height - 4
                    radius: 14
                    color: Appearance.accentColor
                    opacity: ws.focused ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: ws.workspaceId
                        color: Appearance.onAccentColor
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
                    onClicked: Hyprland.dispatch(`workspace ${ws.workspaceId}`)
                    // hovering a workspace with windows lists them next to the bar
                    onEntered: {
                        if (ws.occupied)
                            popup.show(ws.currentWs, ws.mapToItem(null, 0, ws.height / 2).y);
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
