import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell

// Keyboard layout switcher next to the bar: the layouts set up in Hyprland,
// the active one highlighted; click one to switch to it.
PanelWindow {
    id: root

    property var barWindow
    property real anchorX: 0
    property real anchorY: 0
    property bool open: false
    readonly property bool barRight: Config.barPosition === "right"
    // beside a side bar at the pointer's height; above or below a top/bottom bar at its x
    readonly property bool horizontal: Config.barHorizontal
    readonly property real screenWidth: screen ? screen.width : 1280
    readonly property real screenHeight: screen ? screen.height : 800

    // point: centre of the layout label, in bar coordinates
    function show(point) {
        anchorX = point.x;
        anchorY = point.y;
        open = true;
        closeTimer.stop();
    }

    function hideLater() {
        closeTimer.restart();
    }

    screen: barWindow ? barWindow.screen : null
    visible: (open || closeTimer.running) && Keyboard.layouts.length > 0
    exclusiveZone: 0
    implicitWidth: 236
    implicitHeight: list.implicitHeight + 20
    color: "transparent"
    Component.onCompleted: WindowManager.registerBarPopup(root)
    Component.onDestruction: WindowManager.unregisterBarPopup(root)

    anchors {
        top: Config.barPosition !== "bottom"
        bottom: Config.barPosition === "bottom"
        right: barRight
        left: !barRight
    }

    margins {
        top: horizontal ? 5 : Math.max(8, Math.min(anchorY - implicitHeight / 2, screenHeight - implicitHeight - 8))
        bottom: 5
        right: 5
        left: horizontal ? Math.max(8, Math.min(anchorX - implicitWidth / 2, screenWidth - implicitWidth - 8)) : 5
    }

    Timer {
        id: closeTimer

        interval: 220
        onTriggered: root.open = false
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 22
        color: Appearance.panelColor
        border.width: 1
        border.color: Appearance.hairlineColor
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animFast
            }
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    closeTimer.stop();
                else if (root.open)
                    root.hideLater();
            }
        }

        ColumnLayout {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: Keyboard.layouts

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    readonly property bool current: modelData.index === Keyboard.activeIndex
                    readonly property color contentColor: current ? Appearance.onAccentColor : Appearance.fgColor

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 16
                    color: current ? Appearance.accentColor : (rowArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        StyledText {
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignHCenter
                            text: row.modelData.label
                            color: row.contentColor
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: row.contentColor
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        MaterialSymbol {
                            visible: row.current
                            icon: "check"
                            font.pixelSize: 16
                            color: row.contentColor
                        }
                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Keyboard.setLayout(row.modelData.index)
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
