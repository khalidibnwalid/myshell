import "../.."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: wsIndicatorBar

    property int activeIndex: Hyprland.workspaces.values.findIndex((ws) => {
        return ws.focused;
    })

    width: 34
    height: (26 + 8) * Hyprland.workspaces.values.length // 26px + 8px spacing

    // material indicator (vertical)
    Rectangle {
        id: activeIndicator

        width: 36
        height: 36
        radius: 14
        color: Appearance.accentColor
        x: -1
        y: wsIndicatorBar.activeIndex * (26 + 8) - 5
        z: 1
        opacity: 0.3

        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }

        }

    }

    Repeater {
        model: Hyprland.workspaces.values.length

        Rectangle {
            // Behavior on border.color {
            //     ColorAnimation {
            //         duration: 200
            //         easing.type: Easing.InOutQuad
            //     }
            // }

            required property int index

            width: 26
            height: Hyprland.workspaces.values[index].focused ? 26 : 26
            radius: 10
            x: 4
            y: index * (26 + 8)
            color: Hyprland.workspaces.values[index].focused ? Appearance.accentColor : Appearance.highlightColor
            // opacity: Hyprland.workspaces.values[index].focused ? 1.0 : 0.8
            // border.color: Hyprland.workspaces.values[index].focused ? Appearance.accentColor : Appearance.highlightColor
            // border.width: 4
            z: 2

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Hyprland.workspaces.values[index].activate();
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.InOutQuad
                }

            }

        }

    }

}
