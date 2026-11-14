import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// System tray: the first `maxVisible` icons, the rest behind an arrow.
// Left or right click opens the item's menu, middle click activates the app.
GridLayout {
    id: root

    property var barWindow
    property int maxVisible: Math.max(1, Config.bar.trayVisible)
    property bool expanded: false
    // tray apps that are not hidden in the settings
    readonly property var items: SystemTray.items.values.filter(i => Config.trayHiddenList.indexOf(i.id) < 0)
    readonly property int count: items.length
    readonly property bool horizontal: Config.barHorizontal

    // a column on a side bar, a row on a top or bottom bar
    columns: horizontal ? -1 : 1
    rowSpacing: 6
    columnSpacing: 6

    // overflow arrow
    Item {
        visible: root.count > root.maxVisible
        Layout.alignment: Qt.AlignCenter
        implicitWidth: root.horizontal ? 20 : 28
        implicitHeight: root.horizontal ? 28 : 20

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: arrowArea.containsMouse || root.expanded ? Appearance.surfaceHighColor : Appearance.surfaceColor

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animFast
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            icon: "keyboard_arrow_up"
            font.pixelSize: 18
            color: Appearance.fgColor
            rotation: (root.horizontal ? -90 : 0) + (root.expanded ? 180 : 0)

            Behavior on rotation {
                NumberAnimation {
                    duration: Appearance.animNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeOut
                }
            }
        }

        MouseArea {
            id: arrowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Repeater {
        model: root.items

        delegate: Item {
            id: trayItem

            required property var modelData
            required property int index
            // the last `maxVisible` icons stay next to the status icons; the others unfold above them
            readonly property bool shown: root.expanded || index >= root.count - root.maxVisible

            function openMenu() {
                if (!modelData.hasMenu)
                    return;
                if (menu.open && menu.item === modelData) {
                    menu.open = false;
                    return;
                }
                menu.show(modelData, trayItem.mapToItem(null, trayItem.width / 2, trayItem.height / 2));
            }

            visible: shown
            Layout.alignment: Qt.AlignCenter
            implicitWidth: 30
            implicitHeight: 30

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Appearance.surfaceHighColor
                opacity: iconArea.containsMouse || (menu.open && menu.item === trayItem.modelData) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animFast
                    }
                }
            }

            IconImage {
                anchors.centerIn: parent
                source: trayItem.modelData.icon
                implicitSize: 20
                scale: iconArea.pressed ? 0.88 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animFast
                    }
                }
            }

            MouseArea {
                id: iconArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                // left / right click: the menu (or the app itself if it has none); middle click: activate the app
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton || !trayItem.modelData.hasMenu)
                        trayItem.modelData.activate();
                    else
                        trayItem.openMenu();
                }
                onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }

    TrayMenu {
        id: menu

        barWindow: root.barWindow
        screen: root.barWindow ? root.barWindow.screen : null
    }
}
