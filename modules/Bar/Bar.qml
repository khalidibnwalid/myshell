import "../../config/"
import "../../components/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell

Scope {
    id: root

    Binding {
        target: WindowManager
        property: "barWindows"
        value: bars.instances
    }

    Variants {
        id: bars

        model: Quickshell.screens

        PanelWindow {
            id: panelWindow

            required property var modelData

            readonly property bool horizontal: Config.barHorizontal
            // 0 while the bar has a background (45% and up), 1 once it is see-through: the groups of
            // icons then sit on floating "islands" (like the clock) instead of bare wallpaper
            readonly property real islandAmount: Appearance.barIslandAmount
            readonly property int islandPadding: 7
            // the look (classic, capsule, islands, inset). The floating styles leave a gap to the
            // screen edge and none on the side of the windows, so gap + shape = the bar's size
            // whatever the style; along the bar the gap is the same at both ends.
            readonly property string style: Appearance.barStyle
            readonly property bool islands: style === "islands"
            readonly property int margin: Appearance.barEdgeMargin
            readonly property int mLeft: horizontal ? margin : (Config.barPosition === "left" ? margin : Appearance.barInnerMargin)
            readonly property int mRight: horizontal ? margin : (Config.barPosition === "right" ? margin : Appearance.barInnerMargin)
            readonly property int mTop: horizontal ? (Config.barPosition === "top" ? margin : Appearance.barInnerMargin) : margin
            readonly property int mBottom: horizontal ? (Config.barPosition === "bottom" ? margin : Appearance.barInnerMargin) : margin
            // the centre of the shape, across the bar, relative to the window's centre
            readonly property real shiftX: (mLeft - mRight) / 2
            readonly property real shiftY: (mTop - mBottom) / 2

            screen: modelData
            visible: true
            implicitWidth: Config.barSize
            implicitHeight: Config.barSize
            color: "transparent"

            // a side bar spans the screen's height, a top or bottom bar its width
            anchors {
                top: Config.barPosition !== "bottom"
                bottom: Config.barPosition !== "top"
                left: Config.barPosition !== "right"
                right: Config.barPosition !== "left"
            }

            // The bar's background (blurred by the compositor when it is see-through).
            // Classic: the whole strip. Capsule: one rounded shape inside the margin.
            // Inset: a solid strip (the rounded screen corners are in the corner windows below).
            // Islands: none, every group has its own.
            Rectangle {
                visible: !panelWindow.islands
                x: panelWindow.mLeft
                y: panelWindow.mTop
                width: parent.width - panelWindow.mLeft - panelWindow.mRight
                height: parent.height - panelWindow.mTop - panelWindow.mBottom
                radius: panelWindow.style === "capsule" ? Math.min(width, height) / 2 : 0
                color: panelWindow.style === "inset" ? Qt.alpha(Appearance.bgColor, 1) : Appearance.panelColor
                border.width: panelWindow.style === "capsule" ? 1 : 0
                border.color: Qt.alpha(Appearance.fgColor, 0.1)
            }

            // start: search + workspaces
            Rectangle {
                x: panelWindow.islands && !panelWindow.horizontal ? panelWindow.mLeft : startGroup.x - panelWindow.islandPadding
                y: panelWindow.islands && panelWindow.horizontal ? panelWindow.mTop : startGroup.y - panelWindow.islandPadding
                width: panelWindow.islands && !panelWindow.horizontal ? parent.width - panelWindow.mLeft - panelWindow.mRight : startGroup.width + panelWindow.islandPadding * 2
                height: panelWindow.islands && panelWindow.horizontal ? parent.height - panelWindow.mTop - panelWindow.mBottom : startGroup.height + panelWindow.islandPadding * 2
                radius: Math.min(width, height) / 2 > 24 ? 24 : Math.min(width, height) / 2
                color: Qt.alpha(Appearance.bgColor, 0.5 * panelWindow.islandAmount)
                border.width: 1
                border.color: Qt.alpha(Appearance.fgColor, 0.1 * panelWindow.islandAmount)
                visible: panelWindow.islandAmount > 0
            }

            GridLayout {
                id: startGroup

                x: panelWindow.horizontal ? 12 + panelWindow.mLeft : Math.round((parent.width - width) / 2 + panelWindow.shiftX)
                y: panelWindow.horizontal ? Math.round((parent.height - height) / 2 + panelWindow.shiftY) : 8 + panelWindow.mTop
                columns: panelWindow.horizontal ? -1 : 1
                rowSpacing: 14
                columnSpacing: 14

                // search / launcher button
                Rectangle {
                    Layout.alignment: Qt.AlignCenter
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    color: WindowManager.searchVisible ? Appearance.accentColor : (searchArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor)
                    scale: searchArea.pressed ? 0.92 : 1

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: "apps"
                        font.pixelSize: 20
                        color: WindowManager.searchVisible ? Appearance.accentContrastColor : Appearance.fgColor
                    }

                    MouseArea {
                        id: searchArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WindowManager.toggleSearchVisible()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }

                BarWS {
                    Layout.alignment: Qt.AlignCenter
                    barWindow: panelWindow
                }
            }

            // middle: clock
            BarClock {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: panelWindow.horizontal ? 0 : panelWindow.shiftX
                anchors.verticalCenterOffset: panelWindow.horizontal ? panelWindow.shiftY : 20
            }

            // end: tray + status icons
            Rectangle {
                x: panelWindow.islands && !panelWindow.horizontal ? panelWindow.mLeft : endGroup.x - panelWindow.islandPadding
                y: panelWindow.islands && panelWindow.horizontal ? panelWindow.mTop : endGroup.y - panelWindow.islandPadding
                width: panelWindow.islands && !panelWindow.horizontal ? parent.width - panelWindow.mLeft - panelWindow.mRight : endGroup.width + panelWindow.islandPadding * 2
                height: panelWindow.islands && panelWindow.horizontal ? parent.height - panelWindow.mTop - panelWindow.mBottom : endGroup.height + panelWindow.islandPadding * 2
                radius: Math.min(width, height) / 2 > 24 ? 24 : Math.min(width, height) / 2
                color: Qt.alpha(Appearance.bgColor, 0.5 * panelWindow.islandAmount)
                border.width: 1
                border.color: Qt.alpha(Appearance.fgColor, 0.1 * panelWindow.islandAmount)
                visible: panelWindow.islandAmount > 0
            }

            GridLayout {
                id: endGroup

                x: panelWindow.horizontal ? parent.width - width - 12 - panelWindow.mRight : Math.round((parent.width - width) / 2 + panelWindow.shiftX)
                y: panelWindow.horizontal ? Math.round((parent.height - height) / 2 + panelWindow.shiftY) : parent.height - height - 16 - panelWindow.mBottom
                columns: panelWindow.horizontal ? -1 : 1
                rowSpacing: 10
                columnSpacing: 10

                BarTrays {
                    Layout.alignment: Qt.AlignCenter
                    barWindow: panelWindow
                }

                BarBottomItems {
                    Layout.alignment: Qt.AlignCenter
                    barWindow: panelWindow
                }
            }
        }
    }

    // The Inset style: the desktop looks like a rounded sheet beside a solid bar. The bar's colour
    // fills the corner where the sheet would be rounded: four small windows, two per screen (at
    // each end of the bar's inner edge), that take no room and let clicks through.
    // both ends of every screen's bar: [{ screen, atEnd }]
    readonly property var cornerList: {
        const out = [];
        for (const screen of Quickshell.screens) {
            out.push({
                "screen": screen,
                "atEnd": false
            });
            out.push({
                "screen": screen,
                "atEnd": true
            });
        }
        return out;
    }

    Variants {
        id: corners

        model: Appearance.barStyle === "inset" ? root.cornerList : []

        BarCorner {
            required property var modelData

            screen: modelData.screen
            atEnd: modelData.atEnd
        }
    }
}
