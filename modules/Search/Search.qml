import "../../config/"
import "../../components"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
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

                property var allApps: []
                property var results: []
                property int maxVisibleResults: 7
                property int resultHeight: 40
                property int baseHeight: 70
                property int listHeight: results.length > 0 ? Math.min(results.length, maxVisibleResults) * (resultHeight + 24) + 32 : 0
                property int dynamicHeight: baseHeight + listHeight

                color: "transparent"
                implicitWidth: 700
                implicitHeight: dynamicHeight
                focusable: true

                Component.onCompleted: {
                    allApps = DesktopEntries.applications.values.map(entry => ({
                                "name": entry.name,
                                "description": entry.comment,
                                "image": entry.icon,
                                // if set will use a material icon
                                "icon": undefined,
                                "execute": entry.execute // shoudle be a function, optional
                            }));
                }

                // TODO: turn this into a service
                // created this to capture stdout from process and await them,
                // since I didn't find a way to run a command and await its result,
                // qml js doesn't support async/await, and I didn't find a way to run commands inside js
                property var stdCollectFn
                Process {
                    id: proc

                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: panelWindow.stdCollectFn(this.text)
                    }

                    // will execute a command and put its output in results array
                    // @param {string[]}
                    //
                    function execSingle(cmd, desc, icon) {
                        proc.command = cmd;
                        proc.running = true;
                        panelWindow.stdCollectFn = text => {
                            results = [
                                {
                                    name: text.trim(),
                                    description: desc,
                                    icon: icon || "terminal"
                                }
                            ];
                        };
                    }
                }

                function filterResults() {
                    const query = searchField.text.toLowerCase();
                    if (query.trim() === "") {
                        panelWindow.results = [];
                    } else if (query.includes(":")) {
                        // direct launch
                        const regex = /:(?<flag>\w+)/g;
                        const flags = [];

                        let match;
                        while ((match = regex.exec(query)) !== null) {
                            flags.push(match.groups && match.groups.flag ? match.groups.flag : match[1]);
                        }

                        const data = query.replace(regex, "").trim();

                        const queryCommand = query.split(":")[0].trim();
                        if (flags.length > 0) {
                            switch (flags[0]) {
                            // not all flags support multiple flags
                            // TODO: a way to add this in configs
                            case "?":
                            case "h":
                            case "help":
                                panelWindow.results = [
                                    {
                                        name: "Available commands",
                                        description: "List of available commands",
                                        icon: "help"
                                    },
                                    {
                                        name: ":app or :a",
                                        description: "List all applications",
                                        icon: "apps"
                                    },
                                    {
                                        name: ":calc or :c or :calculator",
                                        description: "Simple calculator using bc",
                                        icon: "calculate"
                                    }
                                ];
                                break;
                            case "a":
                            case "app":
                                panelWindow.results = panelWindow.allApps;
                                break;
                            case "c":
                            case "calc":
                            case "calculator":
                                const cmd = ["sh", "-c", "echo " + data + " | bc"];
                                proc.execSingle(cmd, "Calculator", "calculate");
                                break;
                            }
                        } else {
                            panelWindow.results = [];
                        }
                    } else {
                        let scoredResults = panelWindow.allApps.map(item => {
                            const name = item.name.toLowerCase();
                            const description = item.description ? item.description.toLowerCase() : "";
                            // higher is better, if zero then exclude
                            let priority = 0;
                            if (name.startsWith(query)) {
                                priority = 2;
                            } else if (name.includes(query)) {
                                priority = 1;
                            } else if (description.includes(query)) {
                                priority = 0.5;
                            }
                            item.priority = priority;
                            return item;
                        });

                        const filtered = scoredResults.filter(item => item.priority > 0);
                        const sorted = filtered.sort((a, b) => b.priority - a.priority);
                        panelWindow.results = sorted;
                    }

                    if (panelWindow.results.length > 0)
                        resultsView.currentIndex = 0;
                    else
                        resultsView.currentIndex = -1;
                }

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
                        height: parent.height
                        color: Appearance.bgColor
                        radius: 30
                        opacity: 0.32
                        z: 1
                        border.color: Appearance.borderColor
                        border.width: 1

                        Behavior on height {
                            NumberAnimation {
                                duration: 150
                            }
                        }
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
                            Layout.bottomMargin: panelWindow.results.length > 0 ? 0 : 16

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
                                placeholderText: "`:h` for help"
                                height: 50
                                font.pixelSize: 22
                                selectByMouse: true
                                Keys.onReleased: event => {
                                    if (event.key === Qt.Key_Down) {
                                        resultsView.currentIndex = Math.min(resultsView.count - 1, resultsView.currentIndex + 1);
                                    } else if (event.key === Qt.Key_Up) {
                                        resultsView.currentIndex = Math.max(0, resultsView.currentIndex - 1);
                                    } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                        if (resultsView.currentIndex >= 0) {
                                            resultsView.model[resultsView.currentIndex]?.execute();
                                            lazyloader.active = false;
                                        }
                                    } else if (event.key === Qt.Key_Escape) {
                                        lazyloader.active = false;
                                    } else {
                                        panelWindow.filterResults();
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
                            //Layout.preferredHeight: filteredResults.length > 0 ? Math.min(filteredResults.length, maxVisibleResults) * (resultHeight + 4) + 16 : 0
                            Layout.fillHeight: true

                            ListView {
                                id: resultsView

                                anchors.fill: parent
                                spacing: 12
                                model: panelWindow.results
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
                                    height: resultsView.currentIndex === index ? panelWindow.resultHeight + 24 : panelWindow.resultHeight + 12
                                    color: 'transparent'
                                    radius: 20

                                    RowLayout {
                                        spacing: 16
                                        Layout.alignment: Qt.AlignVCenter
                                        anchors.fill: parent
                                        anchors.leftMargin: 30

                                        MaterialSymbol {
                                            visible: !(modelData?.image?.length > 0) && modelData?.icon?.length > 0
                                            icon: modelData.icon
                                            color: Appearance.fgColor
                                            font.pixelSize: 46
                                            opacity: 0.8
                                        }
                                        Image {
                                            visible: modelData?.image?.length > 0 && !modelData?.icon?.length > 0
                                            source: "image://icon/" + modelData.image
                                            Layout.preferredHeight: 46
                                            Layout.preferredWidth: 46
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        ColumnLayout {
                                            spacing: -4
                                            Layout.fillWidth: true
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                color: Appearance.fgColor
                                                font.pixelSize: 24
                                                font.weight: resultsView.currentIndex === index ? Font.Normal : Font.Light
                                            }
                                            Text {
                                                text: modelData.description
                                                font.pixelSize: 14
                                                font.weight: Font.Light
                                                visible: modelData.description && modelData.description.length > 0
                                                color: Appearance.fgColor
                                                opacity: 0.8
                                                elide: Text.ElideRight
                                                width: parent.width - 100
                                            }
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

                                width: parent.width - 20
                                height: panelWindow.resultHeight + 30
                                radius: 20
                                color: Appearance.accentColor
                                anchors.horizontalCenter: parent.horizontalCenter
                                opacity: 0.2
                                visible: resultsView.currentIndex >= 0 && panelWindow.results.length > 0
                                y: resultsView.currentItem ? resultsView.currentItem.y - resultsView.contentY : 0
                                z: -1

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: parent.radius
                                    border.color: Appearance.accentColor
                                    border.width: 2
                                }

                                Behavior on y {
                                    NumberAnimation {
                                        duration: 25
                                        easing.type: Easing.InQuad
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
