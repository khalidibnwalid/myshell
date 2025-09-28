import "../.."
import "../../components"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland

Scope {
    // bind = $mainMod, SPACE, global, quickshell:search
    GlobalShortcut {
        name: "search"
        onPressed: lazyloader.active = !lazyloader.active
    }

    LazyLoader {
        id: lazyloader

        active: false

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: panelWindow

                property var listResults: ["Calculator", "Calculators", "Cal", "Cal 2", "Terminal", "Browser", "Settings", "Files", "Music", "Notes"]
                property var filteredResults: []
                property int maxVisibleResults: 5
                property int resultHeight: 40
                property int baseHeight: 70 // field + margins
                property int dynamicHeight: baseHeight + (filteredResults.length > 0 ? Math.min(filteredResults.length, maxVisibleResults) * (resultHeight + 10) + 16 : 0)

                color: "transparent"
                implicitWidth: 700
                implicitHeight: dynamicHeight
                focusable: true

                Item {
                    width: parent.width
                    height: parent.height
                    transformOrigin: Item.Center

                    // Behavior on width {
                    //     NumberAnimation {
                    //         duration: 150
                    //         easing.type: Easing.InOutQuad
                    //     }
                    // }

                    // Background
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        implicitHeight: parent.height
                        color: Appearance.bgColor
                        radius: 30
                        opacity: 0.32
                        z: 1
                        border.color: Appearance.accentColor
                        border.width: 1
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        Layout.alignment: Qt.AlignCenter
                        spacing: 16
                        clip: true
                        z: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0
                            Layout.topMargin: 16
                            Layout.leftMargin: 24
                            Layout.rightMargin: 24
                            Layout.bottomMargin: panelWindow.filteredResults.length > 0 ? 0 : 16

                            MaterialSymbol {
                                icon: "search"
                                // fill: 1
                                // grad: 0
                                color: Appearance.fgColor
                                font.pixelSize: 32
                                opacity: 0.8
                                // leftPadding: 16
                                rightPadding: 8
                            }
                            // Search input

                            TextField {
                                id: searchField

                                color: Appearance.fgColor
                                placeholderTextColor: Appearance.fgColor
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                placeholderText: "Search..."
                                height: 50
                                font.pixelSize: 22
                                selectByMouse: true
                                Keys.onReleased: (event) => {
                                    if (event.key === Qt.Key_Down) {
                                        resultsView.currentIndex = Math.min(resultsView.count - 1, resultsView.currentIndex + 1);
                                    } else if (event.key === Qt.Key_Up) {
                                        resultsView.currentIndex = Math.max(0, resultsView.currentIndex - 1);
                                    } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                        if (resultsView.currentIndex >= 0)
                                            console.log("Selected:", resultsView.model[resultsView.currentIndex]);

                                    } else if (event.key === Qt.Key_Escape) {
                                        panelWindow.visible = false;
                                    } else {
                                        const query = searchField.text.toLowerCase();
                                        let newResults = query.trim() === "" ? [] : panelWindow.listResults.filter((item) => {
                                            return item.toLowerCase().startsWith(query);
                                        });
                                        panelWindow.filteredResults = newResults;
                                        // Auto-select first result when search updates
                                        if (newResults.length > 0)
                                            resultsView.currentIndex = 0;
                                        else
                                            resultsView.currentIndex = -1;
                                    }
                                }
                                Component.onCompleted: {
                                    searchField.forceActiveFocus();
                                }

                                background: Rectangle {
                                    color: 'transparent'
                                }

                            }

                        }

                        // Results list
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: filteredResults.length > 0 ? Math.min(filteredResults.length, maxVisibleResults) * (resultHeight + 4) + 16 : 0

                            ListView {
                                id: resultsView

                                anchors.fill: parent
                                spacing: 4
                                model: panelWindow.filteredResults
                                currentIndex: -1
                                clip: true

                                add: Transition {
                                    NumberAnimation {
                                        properties: "opacity, y"
                                        from: 0
                                        to: 1
                                        duration: 200
                                    }

                                    NumberAnimation {
                                        properties: "y"
                                        from: 20
                                        to: 0
                                        duration: 200
                                    }

                                }

                                remove: Transition {
                                    NumberAnimation {
                                        properties: "opacity, y"
                                        from: 1
                                        to: 0
                                        duration: 200
                                    }

                                    NumberAnimation {
                                        properties: "y"
                                        from: 0
                                        to: 20
                                        duration: 200
                                    }

                                }

                                delegate: Rectangle {
                                    width: parent.width - 60
                                    height: resultsView.currentIndex === index ? panelWindow.resultHeight + 12 : panelWindow.resultHeight
                                    color: 'transparent'
                                    radius: 20

                                    RowLayout {
                                        Layout.alignment: Qt.AlignVCenter
                                        anchors.fill: parent
                                        anchors.leftMargin: 40

                                        Text {
                                            text: modelData
                                            color: Appearance.fgColor
                                            font.pixelSize: resultsView.currentIndex === index ? 24 : 18
                                            font.weight: resultsView.currentIndex === index ? Font.DemiBold : Font.Normal
                                        }

                                    }

                                    Behavior on height {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.InQuad
                                        }

                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                            easing.type: Easing.InOutQuad
                                        }

                                    }

                                }

                            }

                            // active result indicator
                            Rectangle {
                                id: activeIndicator

                                width: parent.width - 30
                                height: panelWindow.resultHeight + 20
                                radius: 20
                                color: Appearance.accentColor
                                anchors.horizontalCenter: parent.horizontalCenter
                                opacity: 0.1
                                visible: resultsView.currentIndex >= 0 && panelWindow.filteredResults.length > 0
                                y: resultsView.currentIndex < 0 ? 0 : resultsView.currentIndex * (panelWindow.resultHeight + resultsView.spacing) - 5
                                z: 4

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: parent.radius
                                    border.color: Appearance.accentColor
                                    border.width: 2
                                }

                                Behavior on y {
                                    NumberAnimation {
                                        duration: 100
                                        easing.type: Easing.InOutQuad
                                    }

                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }

                                }

                            }

                            Behavior on Layout.preferredHeight {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }

                            }

                        }

                    }

                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: 25
                            easing.type: Easing.InCubic
                        }

                    }

                }

            }

        }

    }

}
