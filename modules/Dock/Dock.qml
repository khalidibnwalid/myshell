import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWindow

            required property var modelData

            screen: modelData
            height: 80 
            color: "transparent"

            anchors {
                bottom: true
                left: true
                right: true
            }

            // Mouse detection area for the entire dock panel
            MouseArea {
                id: dockHoverArea
                anchors.fill: parent
                hoverEnabled: true
                // We want clicks to pass through if they aren't on the dock itself, but 
                // since the dock is the only thing here, it's fine.
                // IMPORTANT: We must ensure we don't block clicks to the desktop if possible, 
                // but standard PanelWindow behavior usually reserves space or sits on top.
                // For a true "overlay" that doesn't block, Quickshell might require specific layer settings 
                // or input region management, but for now we implement the visual slide.
                propagateComposedEvents: true
                onClicked: mouse.accepted = false
                z: -1 // Behind the dock content
            }

            Rectangle {
                id: dockVisual
                // Anchor horizontally centered
                anchors.horizontalCenter: parent.horizontalCenter
                
                // Vertical positioning logic
                // If hovered, y is centered-ish (or fixed padding from bottom)
                // If not hovered, y pushes it down off screen
                // parent.height is 80. Dock height is 64.
                // Visible y position: (80 - 64) / 2 = 8
                // Hidden y position: 80 (fully below) or 75 (little peek)
                y: (dockHoverArea.containsMouse || flow.hovered) ? 8 : 120

                Behavior on y {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }

                // Smoothly animate width changes
                width: flow.implicitWidth + 30
                height: 64
                color: Appearance.bgColor
                radius: 32 // More rounded, pill shape
                border.width: 1
                border.color: Appearance.borderColor
                opacity: (dockHoverArea.containsMouse || flow.hovered) ? 0.95 : 0.0

                Behavior on opacity {
                     NumberAnimation { duration: 300 }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }

                RowLayout {
                    id: flow

                    property bool hovered: false
                    // Backup check if mouse is over icons but not main area (rare but possible with transforms)
                    
                    anchors.centerIn: parent
                    spacing: 12

                    Repeater {
                        model: [] 

                        delegate: Item {
                            width: 48
                            height: 48
                            
                            property bool hovered: false

                            scale: hovered ? 1.2 : 1.0
                            transform: Translate {
                                y: hovered ? -10 : 0
                                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                            }

                            Behavior on scale { 
                                NumberAnimation { 
                                    duration: 200; 
                                    easing.type: Easing.OutBack 
                                } 
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: {
                                    Quickshell.execDetached([modelData.cmd]);
                                }
                            }
                            
                            IconImage {
                                anchors.fill: parent
                                source: Quickshell.iconPath(modelData.icon, "image-missing")
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 32
                        color: Appearance.borderColor
                        visible: false 
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Running Apps
                    Repeater {
                        model: Hyprland.toplevels.values
                        
                        delegate: Item {
                            width: 48
                            height: 48
                            
                            property bool hovered: false
                            property var toplevelData: modelData.lastIpcObject

                            scale: hovered ? 1.2 : 1.0
                            transform: Translate {
                                y: hovered ? -8 : 0
                                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                            }

                            Behavior on scale { 
                                NumberAnimation { 
                                    duration: 300; 
                                    easing.type: Easing.OutBack 
                                } 
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: {
                                    parent.hovered = true
                                    flow.hovered = true
                                }
                                onExited: {
                                    parent.hovered = false
                                    flow.hovered = false
                                }
                                onClicked: {
                                    if (modelData.wayland) {
                                        modelData.wayland.activate()
                                    }
                                }
                            }
                            
                            IconImage {
                                anchors.fill: parent
                                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(toplevelData.class)?.icon || "application-x-executable", "image-missing")
                            }

                            // Active indicator style
                            Rectangle {
                                width: parent.hovered ? 20 : 6
                                height: 4
                                radius: 2
                                color: Appearance.accentColor
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: -2
                                
                                Behavior on width {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
