import "../../config/"
import "../../services"
import "../Notifications"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

Scope {
    id: root

    readonly property bool open: WindowManager.quickSettingsVisible
    // keep the window mapped while the closing animation runs
    readonly property bool isActuallyOpen: open || closeTimer.running
    readonly property int panelWidth: 412
    readonly property int gap: 12

    Connections {
        function onQuickSettingsVisibleChanged() {
            if (!WindowManager.quickSettingsVisible)
                closeTimer.restart();
        }

        target: WindowManager
    }

    Timer {
        id: closeTimer

        interval: Appearance.animFast + 30
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
            readonly property bool barRight: Config.layout.barPosition === "right"
            readonly property bool hasNotifications: NotificationService.count > 0
            // start the entrance only once the surface is really on screen, so no frame of it is lost
            readonly property bool shown: root.open && backingWindowVisible

            // the card resizes inside a fixed window, so page changes never resize the surface
            // and it never gets shorter than the main page, so sub-pages do not collapse it
            property Item mainPage: null
            property real cardHeight: Math.min(height, Math.max(280, mainPage ? mainPage.implicitHeight : 0, stackView.currentItem ? stackView.currentItem.implicitHeight : 0))

            screen: modelData
            visible: root.isActuallyOpen
            implicitWidth: root.panelWidth
            implicitHeight: modelData.height - 20
            color: "transparent"

            anchors {
                right: barRight
                left: !barRight
                bottom: true
            }

            margins {
                right: 10
                left: 10
                bottom: 10
            }

            // only the two cards take input, the rest of the window is click-through
            mask: Region {
                item: panelArea

                Region {
                    item: notifArea
                }
            }

            Item {
                id: panelArea

                y: parent.height - height
                width: root.panelWidth
                height: window.cardHeight
            }

            Item {
                id: notifArea

                // stacked on top of the quick settings card
                y: panelArea.y - root.gap - height
                width: window.hasNotifications ? root.panelWidth : 0
                height: Math.min(notifications.implicitHeight, notifications.maxHeight)
            }

            // both cards open and close together
            Item {
                id: stage

                anchors.fill: parent
                opacity: root.open ? 1 : 0

                transform: Translate {
                    x: window.shown ? 0 : (root.open ? (window.barRight ? 42 : -42) : 0)

                    Behavior on x {
                        NumberAnimation {
                            duration: root.open ? 190 : 0
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.open ? 0 : 110
                        easing.type: Easing.OutCubic
                    }
                }

                NotificationPanel {
                    id: notifications

                    x: notifArea.x
                    y: notifArea.y
                    width: root.panelWidth
                    height: notifArea.height
                    maxHeight: Math.max(120, panelArea.y - root.gap)
                    visible: opacity > 0
                    opacity: window.hasNotifications ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }

                Rectangle {
                    x: panelArea.x
                    y: panelArea.y
                    width: panelArea.width
                    height: panelArea.height
                    // outer radius = inner radius (20) + padding (16)
                    radius: 36
                    color: Appearance.panelColor
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
                                "calendarPageComponent": calendarPageComponent
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
                                duration: 150
                            }

                            NumberAnimation {
                                property: "x"
                                from: 14
                                to: 0
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        pushExit: Transition {
                            NumberAnimation {
                                property: "opacity"
                                to: 0
                                duration: 70
                            }
                        }

                        popEnter: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 150
                            }

                            NumberAnimation {
                                property: "x"
                                from: -14
                                to: 0
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        popExit: Transition {
                            NumberAnimation {
                                property: "opacity"
                                to: 0
                                duration: 70
                            }
                        }
                    }
                }

            }

            Behavior on cardHeight {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
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
                id: mainPageComponent

                MainPage {
                }
            }
        }
    }
}
