import "../.."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: wsIndicatorBar

    property HyprlandWorkspace activeWs: Hyprland.workspaces.values.find((ws) => ws.focused)
    // get the total number of workspaces, by getting the highest ID
    property int _numberOfWS: Hyprland.workspaces.values.length > 0 ? Hyprland.workspaces.values[Hyprland.workspaces.values.length - 1].id : 0

    property int vPadding: 10
    width: 42 // 26px + 16px padding (8px on each side)
    height: column.implicitHeight + (vPadding * 2) // Add vertical padding

    Behavior on height {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutQuad
        }
    }

    // background
    Rectangle {
        anchors.fill: parent
        color: Appearance.bgColor
        radius: 16
        border.color: Appearance.borderColor
        border.width: 2
    }

    // indicator
    Rectangle {
        id: activeIndicator
        width: 26 + vPadding
        height: 46 + vPadding
        radius: 14
        color: Appearance.accentColor
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: 0.3
        
        // Position based on active workspace
        y: {
            if (!activeWs) return 0
            let activeIndex = activeWs.id - 1
            return 10 + activeIndex * (26 + 8) - 5
        }

        Behavior on y {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: parent.radius
            border.color: Appearance.accentColor
            border.width: 2
        }
    }

    Column {
        id: column
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 8

        Repeater {
            model: _numberOfWS + 1 

            delegate: Rectangle {
                id: wsRect

                required property int index
                property int workspaceId: index + 1
                property HyprlandWorkspace currentWs: Hyprland.workspaces.values.find(ws => ws.id === workspaceId) || null
                property list<HyprlandToplevel> workspaceToplevels: currentWs?.toplevels?.values || []

                width: 26
                radius: 10
                implicitHeight: 26
                height: currentWs?.focused ? implicitHeight + 20 : implicitHeight
                color: currentWs?.focused ? Appearance.accentColor : Appearance.highlightColor

                Rectangle {
                    visible: workspaceToplevels.length > 0 && !currentWs?.focused
                    anchors.fill: parent
                    anchors.margins: 4
                    color: Appearance.accentColor
                    opacity: 0.7
                    radius: 6
                    border.width: 1
                    border.color: Appearance.fgColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${workspaceId.toString()}`)
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.InQuad
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
