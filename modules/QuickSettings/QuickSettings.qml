import "../../config/"
import "../../services"
import "../../components/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    LazyLoader {
        id: lazyloader

        active: WindowManager.quickSettingsVisible

        Variants {
            model: Quickshell.screens

            PanelWindow {
                // focus: false

                id: bottomPanel

                required property var modelData

                screen: modelData
                visible: true
                implicitWidth: 440
                implicitHeight: 250
                color: "transparent"

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

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 3

                    GridLayout {
                        id: contentGrid
                        columns: 2
                        rowSpacing: 14
                        columnSpacing: 14
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Button {
                            text: "Wi-Fi"
                            icon: "wifi"
                            endIcon: "arrow_forward_ios"
                        }
                        Button {
                            text: "Bluetooth"
                            icon: "bluetooth"
                            endIcon: "arrow_forward_ios"
                        }
                        Button {
                            text: "Battery"
                            icon: "energy_savings_leaf"
                            endIcon: "arrow_forward_ios"
                        }
                        Button {
                            text: "settings"
                            icon: "settings"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 30
                        anchors.margins: 20

                        MaterialSymbol {
                            icon: "volume_up"
                            color: Appearance.fgColor
                            font.pixelSize: 32
                        }
                        Slider {
                            value: 0
                            width: 330
                            //value: Pipewire.defaultAudioSink?.audio.volume ?? 0
                        }
                    }
                }
            }
        }
    }
}
