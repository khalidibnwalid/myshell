import "../../config/"
import "../../services"
import QtQuick
import QtQuick.Controls
import Quickshell

Scope {
    id: root

    LazyLoader {
        id: lazyloader

        active: WindowManager.quickSettingsVisible

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: bottomPanel
                required property var modelData

                screen: modelData
                visible: true
                implicitWidth: 440
                implicitHeight: stackView?.currentItem?.implicitHeight + 24 < 250 ? 250 : stackView?.currentItem?.implicitHeight + 24
                color: "transparent"

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: 40
                        easing.type: Easing.OutQuad
                    }
                }

                anchors {
                    right: true
                    bottom: true
                }

                margins {
                    right: 10
                    bottom: 10
                }

                // background
                Rectangle {
                    anchors.fill: parent
                    color: Appearance.bgColor
                    radius: 24
                    border.color: Appearance.borderColor
                    border.width: 2
                    opacity: 0.5
                }

                // `Component` will prevent the component from loading immediately,
                // basically lazy loading with a reference
                Component {
                    id: wifiPageComponent
                    WifiPage {}
                }

                Component {
                    id: bluetoothPageComponent
                    BluetoothPage {}
                }

                Component {
                    id: batteryPageComponent
                    BatteryPage {}
                }

                Component {
                    id: mainPageComponent
                    MainPage {}
                }

                StackView {
                    id: stackView
                    anchors.fill: parent
                }

                Component.onCompleted: {
                    if (stackView.depth === 0) {
                        stackView.push(mainPageComponent, {
                            "stackView": stackView,
                            "wifiPageComponent": wifiPageComponent,
                            "bluetoothPageComponent": bluetoothPageComponent,
                            "batteryPageComponent": batteryPageComponent
                        });
                    }
                }
            }
        }
    }
}
