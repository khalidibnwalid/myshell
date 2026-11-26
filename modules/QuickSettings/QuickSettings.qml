import "../../config/"
import "../../services"
import "../Notifications"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    readonly property bool open: WindowManager.quickSettingsVisible
    // Keep the window mapped while the closing animation runs. It is set on opening and cleared only
    // when the close timer ends: a binding on closeTimer.running dropped to false for an instant
    // before the timer restarted, which unmapped the window and made the closing flicker.
    property bool isActuallyOpen: false
    readonly property int panelWidth: 412
    readonly property int gap: 12
    // the panel opens only on the monitor that has focus when it opens (not on every monitor)
    property string targetScreen: ""

    // qs ipc call quicksettings toggle | open | close
    IpcHandler {
        function toggle(): void {
            WindowManager.quickSettingsVisible = !WindowManager.quickSettingsVisible;
        }

        function open(): void {
            WindowManager.quickSettingsVisible = true;
        }

        function close(): void {
            WindowManager.quickSettingsVisible = false;
        }

        target: "quicksettings"
    }

    Connections {
        function onQuickSettingsVisibleChanged() {
            if (WindowManager.quickSettingsVisible) {
                root.targetScreen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
                closeTimer.stop();
                root.isActuallyOpen = true;
            } else {
                closeTimer.restart();
            }
        }

        target: WindowManager
    }

    Timer {
        id: closeTimer

        interval: Appearance.animFast + 30
        onTriggered: root.isActuallyOpen = root.open
    }

    // click anywhere else to dismiss; the bar stays usable so its buttons can toggle
    HyprlandFocusGrab {
        windows: [...panels.instances, ...WindowManager.barWindows, ...WindowManager.barPopups]
        active: root.open
        onCleared: WindowManager.quickSettingsVisible = false
    }

    Variants {
        id: panels

        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            readonly property bool barRight: Config.panelRight
            // The panel follows the bar: it hangs from the top edge under a top bar, and rises from
            // the bottom edge for the other bars (a side bar's status icons are at its bottom).
            readonly property bool fromTop: Config.barPosition === "top"
            readonly property bool hasNotifications: NotificationService.count > 0
            // start the entrance only once the surface is really on screen, so no frame of it is lost
            readonly property bool shown: root.open && backingWindowVisible

            // the card resizes inside a fixed window, so page changes never resize the surface
            // and it never gets shorter than the main page, so sub-pages do not collapse it
            property Item mainPage: null
            property real cardHeight: Math.min(height, Math.max(280, mainPage ? mainPage.implicitHeight : 0, stackView.currentItem ? stackView.currentItem.implicitHeight : 0))

            screen: modelData
            visible: root.isActuallyOpen && modelData.name === root.targetScreen
            focusable: root.open
            implicitWidth: root.panelWidth
            implicitHeight: modelData.height - 20 - (Config.barHorizontal ? Config.barSize : 0)
            color: "transparent"

            anchors {
                right: barRight
                left: !barRight
                top: window.fromTop
                bottom: !window.fromTop
            }

            margins {
                right: 10
                left: 10
                top: window.fromTop ? 10 : 0
                bottom: window.fromTop ? 0 : 10
            }

            // only the cards take input, the rest of the window is click-through
            mask: Region {
                item: panelArea

                Region {
                    item: notifArea
                }

                Region {
                    item: printArea
                }
            }

            Item {
                id: panelArea

                y: window.fromTop ? 0 : parent.height - height
                width: root.panelWidth
                height: window.cardHeight
            }

            // the print queue, between the quick settings card and the notifications, while something prints
            Item {
                id: printArea

                readonly property bool shown: printQueue.shown

                y: window.fromTop ? panelArea.y + panelArea.height + root.gap : panelArea.y - root.gap - height
                width: shown ? root.panelWidth : 0
                height: shown ? printQueue.implicitHeight : 0
            }

            Item {
                id: notifArea

                // stacked on the quick settings card (and the print queue, when it shows): above it, or
                // below it when the panel hangs from the top
                readonly property real edgeY: printArea.shown ? (window.fromTop ? printArea.y + printArea.height : printArea.y) : (window.fromTop ? panelArea.y + panelArea.height : panelArea.y)

                y: window.fromTop ? edgeY + root.gap : edgeY - root.gap - height
                width: window.hasNotifications ? root.panelWidth : 0
                height: Math.min(notifications.implicitHeight, notifications.maxHeight)
            }

            // both cards open and close together
            Item {
                id: stage

                anchors.fill: parent
                // 1 = away (toward the bar), 0 = in place; drives the slide and the slight growth
                property real slide: 1

                opacity: 0

                // It comes out of the bar's corner: it slides in from the bar's side (sideways for a side bar,
                // up or down for the others), grows a little into place and fades in. The entrance starts
                // once the window is really on screen (window.shown) and a frame later, so none of it is lost.
                transform: [
                    Scale {
                        origin.x: window.barRight ? stage.width : 0
                        origin.y: window.fromTop ? 0 : stage.height
                        xScale: 1 - 0.05 * stage.slide
                        yScale: 1 - 0.05 * stage.slide
                    },
                    Translate {
                        x: Config.barHorizontal ? 0 : stage.slide * (window.barRight ? 48 : -48)
                        y: !Config.barHorizontal ? 0 : stage.slide * (window.fromTop ? -48 : 48)
                    }
                ]

                Connections {
                    function onShownChanged() {
                        if (window.shown) {
                            exitAnim.stop();
                            enterAnim.restart();
                        }
                    }

                    target: window
                }

                Connections {
                    function onOpenChanged() {
                        if (!root.open) {
                            enterAnim.stop();
                            exitAnim.restart();
                        }
                    }

                    target: root
                }

                SequentialAnimation {
                    id: enterAnim

                    PropertyAction {
                        target: stage
                        property: "opacity"
                        value: 0
                    }

                    PropertyAction {
                        target: stage
                        property: "slide"
                        value: 1
                    }

                    PauseAnimation {
                        duration: 30
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: stage
                            property: "opacity"
                            to: 1
                            duration: Appearance.animNormal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.easeFade
                        }

                        NumberAnimation {
                            target: stage
                            property: "slide"
                            to: 0
                            duration: Appearance.animSlow
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.easeOut
                        }
                    }
                }

                // out: quicker, back toward the bar; the window stays until closeTimer ends
                ParallelAnimation {
                    id: exitAnim

                    // stays solid a little, then goes quickly: Hyprland's blur behind the panel cannot
                    // fade with it, so the less time the panel is faint, the less the blur shows alone
                    NumberAnimation {
                        target: stage
                        property: "opacity"
                        to: 0
                        duration: 150
                        easing.type: Easing.InQuad
                    }

                    NumberAnimation {
                        target: stage
                        property: "slide"
                        to: 1
                        duration: 150
                        easing.type: Easing.InCubic
                    }
                }

                NotificationPanel {
                    id: notifications

                    x: notifArea.x
                    y: notifArea.y
                    width: root.panelWidth
                    height: notifArea.height
                    maxHeight: Math.max(120, window.fromTop ? window.height - (notifArea.edgeY - panelArea.y) - root.gap : notifArea.edgeY - root.gap)
                    visible: opacity > 0
                    opacity: window.hasNotifications ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animFast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.easeFade
                        }
                    }
                }

                PrintQueueCard {
                    id: printQueue

                    x: printArea.x
                    y: printArea.y
                    width: root.panelWidth
                }

                Rectangle {
                    x: panelArea.x
                    y: panelArea.y
                    width: panelArea.width
                    height: panelArea.height
                    // outer radius = inner radius (20) + padding (16)
                    radius: 36
                    // never more than 15% see-through, whatever the bar opacity is
                    color: Qt.alpha(Appearance.bgColor, Math.max(0.35, Appearance.panelAlpha))
                    border.color: Appearance.hairlineColor
                    border.width: 1
                    Component.onCompleted: {
                        if (stackView.depth === 0)
                            window.mainPage = stackView.push(mainPageComponent, {
                                "stackView": stackView,
                                "networkPageComponent": networkPageComponent,
                                "bluetoothPageComponent": bluetoothPageComponent,
                                "batteryPageComponent": batteryPageComponent,
                                "audioPageComponent": audioPageComponent,
                                "calendarPageComponent": calendarPageComponent,
                                "appsPageComponent": appsPageComponent
                            });
                    }

                    // pages cross-fade quickly with a short nudge in the travel direction
                    StackView {
                        id: stackView

                        clip: true
                        anchors.fill: parent

                        pushEnter: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.easeFade
                            }

                            NumberAnimation {
                                property: "x"
                                from: 14
                                to: 0
                                duration: 240
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.easeStandard
                            }
                        }

                        pushExit: Transition {
                            NumberAnimation {
                                property: "opacity"
                                to: 0
                                duration: 90
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.easeFade
                            }
                        }

                        popEnter: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.easeFade
                            }

                            NumberAnimation {
                                property: "x"
                                from: -14
                                to: 0
                                duration: 240
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.easeStandard
                            }
                        }

                        popExit: Transition {
                            NumberAnimation {
                                property: "opacity"
                                to: 0
                                duration: 90
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.easeFade
                            }
                        }
                    }
                }

            }

            Behavior on cardHeight {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeStandard
                }
            }

            // --- Pages ---
            Component {
                id: networkPageComponent

                NetworkPage {
                }
            }

            Component {
                id: bluetoothPageComponent

                BluetoothPage {
                }
            }

            Component {
                id: batteryPageComponent

                BatteryPage {
                }
            }

            Component {
                id: audioPageComponent

                AudioDevicePage {
                }
            }

            Component {
                id: calendarPageComponent

                CalendarPage {
                }
            }

            Component {
                id: appsPageComponent

                AppsPage {
                }
            }

            Component {
                id: mainPageComponent

                MainPage {
                }
            }
        }
    }
}
