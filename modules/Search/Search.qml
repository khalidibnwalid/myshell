import "../.."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Scope {
    PanelWindow {
        property list<string> listResults: ["Calculator", "Calculators", "Terminal", "Browser", "Settings", "Files", "Music", "Notes"]
        property list<string> filteredResults: []
        property int maxVisibleResults: 5
        property int resultHeight: 40

        id: panelWindow

        color: "transparent"
        implicitWidth: 700
        implicitHeight: 50 + Math.min(filteredResults.length, maxVisibleResults) * resultHeight + 20

        visible: false
        focusable: true


        Rectangle {
            width: parent.width
            implicitHeight: parent.height
            color: Appearance.bgColor
            radius: 40

            ColumnLayout {
                anchors.fill: parent
                Layout.alignment: Qt.AlignCenter
                spacing: 16
                clip: true
                // Search input
                TextField {
                    id: searchField

                    color: "#fff"
                    placeholderTextColor: "#aaa"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    placeholderText: "Search..."

                    height: 50
                    font.pixelSize: 22
                    topPadding: 18
                    leftPadding: 24
                    rightPadding: 24
                    bottomPadding: panelWindow.filteredResults.length > 0 ? 0 : 16

                    selectByMouse: true

                    Keys.onReleased:(event) => {
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
                            let newResults = query.trim() === "" 
                                ? []
                                : panelWindow.listResults.filter((item) => item.toLowerCase().startsWith(query));
                            panelWindow.filteredResults = newResults;

                        }
                    }

                    background: Rectangle {
                        color: 'transparent'
                    }

                    Component.onCompleted: {
                         searchField.forceActiveFocus()
                    }
                }

                // Results list
                ListView {
                    id: resultsView
                    // visible: panelWindow.filteredResults.length > 0
                    implicitHeight: panelWindow.filteredResults.length > 0 ? Math.min(panelWindow.filteredResults.length, panelWindow.maxVisibleResults) * panelWindow.resultHeight : 0
                    implicitWidth: panelWindow.filteredResults.length > 0 ? parent.width : parent.width * 0.8
                    spacing: 4
                    model: panelWindow.filteredResults
                    currentIndex: -1

                    // Animate items in/out
                    add: Transition {
                        NumberAnimation { properties: "opacity,y"; from: 0; to: 1; duration: 200 }
                        NumberAnimation { properties: "y"; from: 20; to: 0; duration: 200 }
                    }
                    remove: Transition {
                        NumberAnimation { properties: "opacity,y"; from: 1; to: 0; duration: 200 }
                        NumberAnimation { properties: "y"; from: 0; to: 20; duration: 200 }
                    }

                    delegate: Rectangle {
                        width: parent.width
                        height: panelWindow.resultHeight
                        color: "transparent"
                        border.color: ListView.isCurrentItem ? Appearance.accentColor : "transparent"
                        border.width: 2
                        // Animate highlight
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        scale: ListView.isCurrentItem ? 1.04 : 1.0

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Appearance.fgColor
                            font.pixelSize: 18
                        }
                    }

                }

            }

        }

    }

}
