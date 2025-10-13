import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"

Item {
    property list<color> accentColors: ["#c2c1ff", "#ffc1c1", "#c1ffc1", "#fff0c2", "#ffc1ff", "#c1ffff"]

    ColumnLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24
        spacing: 20

        Text {
            text: "Appearance Settings"
            font.pixelSize: 32
            font.weight: Font.Bold
            color: Appearance.fgColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Theme"
                font.pixelSize: 18
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignVCenter
            }

            ToggleButton {
                icon: "sunny"
                toggled: false
                Layout.preferredWidth: 60
            }

            ToggleButton {
                icon: "bedtime"
                toggled: true
                Layout.preferredWidth: 60
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Accent Color"
                font.pixelSize: 18
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignVCenter
            }

            RowLayout {
                spacing: 8
                Repeater {
                    model: accentColors
                    delegate: Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: modelData
                        border.color: Appearance.fgColor
                        border.width: parent.activeFocus ? 2 : 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Appearance.accentColor = modelData;
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Font Size"
                font.pixelSize: 18
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignVCenter
            }

            Slider {
                width: 200
                value: 0.5
                onDragged: console.log("Font size:", value)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Bar Position"
                font.pixelSize: 18
                color: Appearance.fgColor
                Layout.alignment: Qt.AlignVCenter
            }

            RowLayout {
                spacing: 8
                Repeater {
                    model: ["left", "right"]
                    delegate: ToggleButton {
                        toggled: Config.layout.barPosition === modelData
                        Layout.preferredWidth: 120
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)

                        onClicked: {
                            Config.layout.barPosition = modelData;
                        }
                    }
                }
            }
        }
    }
}
