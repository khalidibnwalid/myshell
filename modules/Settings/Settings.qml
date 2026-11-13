import "../../components"
import "../../config"
import "../../services/"
import "./pages"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root

    readonly property var pages: [
        {
            "name": "General",
            "icon": "tune"
        },
        {
            "name": "Appearance",
            "icon": "palette"
        },
        {
            "name": "About",
            "icon": "info"
        }
    ]
    property int currentIndex: 0

    width: 820
    height: 560
    title: "Settings"
    visible: WindowManager.settingsVisible
    color: Appearance.bgColor
    onClosing: WindowManager.settingsVisible = false

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // --- sidebar ---
        ColumnLayout {
            Layout.preferredWidth: 216
            Layout.fillHeight: true
            Layout.margins: 12
            spacing: 3

            StyledText {
                Layout.leftMargin: 14
                Layout.topMargin: 14
                Layout.bottomMargin: 14
                text: "Settings"
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            Repeater {
                model: root.pages

                delegate: Rectangle {
                    id: navItem

                    required property var modelData
                    required property int index
                    readonly property bool current: root.currentIndex === index
                    readonly property color contentColor: current ? Appearance.onAccentColor : Appearance.fgColor

                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 22
                    color: current ? Appearance.accentColor : (navArea.containsMouse ? Appearance.surfaceColor : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        MaterialSymbol {
                            icon: navItem.modelData.icon
                            fill: navItem.current ? 1 : 0
                            font.pixelSize: 20
                            color: navItem.contentColor
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: navItem.modelData.name
                            font.weight: Font.Medium
                            color: navItem.contentColor
                        }
                    }

                    MouseArea {
                        id: navArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentIndex = navItem.index
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        // --- page area ---
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
            Layout.leftMargin: 0
            radius: 24
            color: Appearance.surfaceColor

            Repeater {
                model: [generalPage, appearancePage, aboutPage]

                delegate: Loader {
                    id: pageLoader

                    required property var modelData
                    required property int index
                    readonly property bool current: root.currentIndex === index

                    anchors.fill: parent
                    sourceComponent: modelData
                    visible: opacity > 0
                    opacity: current ? 1 : 0

                    // fade + small rise when a page becomes current
                    transform: Translate {
                        y: pageLoader.current ? 0 : 10

                        Behavior on y {
                            NumberAnimation {
                                duration: Appearance.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.easeOut
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }
            }
        }
    }

    Component {
        id: generalPage

        General {
        }
    }

    Component {
        id: appearancePage

        AppearancePage {
        }
    }

    Component {
        id: aboutPage

        About {
        }
    }
}
