import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page

    property list<color> accentColors: ["#EBCB8B", "#c2c1ff", "#ffc1c1", "#c1ffc1", "#d3e3fd", "#ffc1ff", "#c1ffff"]

    title: "Appearance"

    SettingRow {
        Layout.fillWidth: true
        first: true
        title: "Accent colour"
        description: "Used for active tiles, sliders and highlights"

        Repeater {
            model: page.accentColors

            delegate: Rectangle {
                id: swatch

                required property color modelData
                readonly property bool current: Qt.colorEqual(Appearance.accentColor, modelData)

                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: modelData
                scale: swatchArea.pressed ? 0.9 : (swatchArea.containsMouse ? 1.1 : 1)

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: swatch.current
                    icon: "check"
                    font.pixelSize: 16
                    color: Appearance.bgColor
                }

                MouseArea {
                    id: swatchArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Config.appearance.accentColor = swatch.modelData.toString();
                        Config.appearance.accentColorLight = Qt.lighter(swatch.modelData, 1.12).toString();
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    SettingRow {
        Layout.fillWidth: true
        title: "Panel opacity"
        description: "How see-through the bar and panels are (" + Math.round(Appearance.panelOpacity * 100) + "%)"

        PillSlider {
            implicitWidth: 220
            implicitHeight: 36
            icon: "opacity"
            // slider covers 35% – 100%
            value: (Appearance.panelOpacity - 0.35) / 0.65
            onDragged: v => Config.appearance.opacity = Math.round((0.35 + v * 0.65) * 100) / 100
        }
    }

    SettingRow {
        Layout.fillWidth: true
        last: true
        title: "Bar position"
        description: "Which edge of the screen the bar sits on"

        Repeater {
            model: ["left", "right"]

            delegate: PillButton {
                required property string modelData

                toggled: Config.layout.barPosition === modelData
                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                onClicked: Config.layout.barPosition = modelData
            }
        }
    }
}
