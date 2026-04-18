import "../../config/"
import "../../services"
import QtQuick
import QtQuick.Controls
import Quickshell

Scope {
    id: root

    // Tracking for opening/closing animation
    property bool isActuallyOpen: WindowManager.quickSettingsVisible || closeTimer.running

    Connections {
        function onQuickSettingsVisibleChanged() {
            if (!WindowManager.quickSettingsVisible)
                closeTimer.restart();

        }

        target: WindowManager
    }

    Timer {
        id: closeTimer

        interval: 350
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bottomPanel

            required property var modelData

            screen: modelData
            visible: isActuallyOpen
            implicitWidth: 460
            implicitHeight: Math.max(400, (stackView.currentItem ? stackView.currentItem.implicitHeight : 0) + 24)
            color: "transparent"

            anchors {
                right: Config.layout.barPosition === "right"
                left: Config.layout.barPosition === "left"
                bottom: true
            }

            margins {
                right: Config.layout.barPosition === "right" ? 10 : 0
                left: Config.layout.barPosition === "left" ? 10 : 0
                bottom: 15
            }

            // Visual Content and Animation Wrapper
            Item {
                id: animationWrapper

                anchors.fill: parent
                // Animation properties
                opacity: WindowManager.quickSettingsVisible ? 1 : 0
                scale: WindowManager.quickSettingsVisible ? 1 : 0.94
                y: WindowManager.quickSettingsVisible ? 0 : 30
                Component.onCompleted: {
                    if (stackView.depth === 0)
                        stackView.push(mainPageComponent, {
                        "stackView": stackView,
                        "networkPageComponent": networkPageComponent,
                        "bluetoothPageComponent": bluetoothPageComponent,
                        "batteryPageComponent": batteryPageComponent
                    });

                }

                // The actual background/panel
                Rectangle {
                    anchors.fill: parent
                    color: Appearance.bgColor
                    radius: 16
                    border.color: Appearance.borderColor
                    border.width: 1

                    // Premium Inner Highlight (Creates the "top-lit" glass effect)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "transparent"
                        radius: 15
                        border.color: "white"
                        border.width: 1
                        opacity: 0.04
                    }

                    // Soft light gradient for subtle depth
                    Rectangle {
                        anchors.fill: parent
                        radius: 24
                        opacity: 0.03

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: "white"
                            }

                            GradientStop {
                                position: 0.4
                                color: "transparent"
                            }

                        }

                    }

                }

                StackView {
                    id: stackView

                    clip: true
                    anchors.fill: parent

                    // Add a nice transition for page switching too
                    replaceEnter: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 200
                        }

                        NumberAnimation {
                            property: "x"
                            from: 30
                            to: 0
                            duration: 250
                            easing.type: Easing.OutCubic
                        }

                    }

                    replaceExit: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: 150
                        }

                        NumberAnimation {
                            property: "x"
                            from: 0
                            to: -30
                            duration: 200
                            easing.type: Easing.InCubic
                        }

                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutBack
                    }

                }

                Behavior on y {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutQuint
                    }

                }

            }

            // --- Navigation Components ---
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
                id: mainPageComponent

                MainPage {
                }

            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.InOutQuad
                }

            }

        }

    }

}
