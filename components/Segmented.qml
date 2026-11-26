import "../config/"
import QtQuick

// A few options side by side; the current one is filled with the accent colour.
// model: strings, or { label, value } objects
Rectangle {
    id: root

    property var model: []
    property var value

    signal selected(var value)

    function step(by) {
        const values = model.map(m => m !== null && typeof m === "object" ? m.value : m);
        const at = values.indexOf(value);
        const next = Math.max(0, Math.min(values.length - 1, (at < 0 ? 0 : at) + by));
        if (values.length > 0 && next !== at)
            selected(values[next]);
    }

    activeFocusOnTab: true
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onShortcutOverride: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right)
            event.accepted = true;
    }

    implicitHeight: 36
    implicitWidth: row.implicitWidth + 6
    radius: height / 2
    color: Appearance.surfaceColor
    opacity: enabled ? 1 : 0.45

    FocusRing {
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.model

            delegate: Rectangle {
                id: option

                required property var modelData
                readonly property bool isObject: modelData !== null && typeof modelData === "object"
                readonly property var itemValue: isObject ? modelData.value : modelData
                readonly property bool current: itemValue === root.value

                height: 30
                width: label.implicitWidth + 26
                radius: 15
                color: current ? Appearance.accentColor : (optionArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

                StyledText {
                    id: label

                    anchors.centerIn: parent
                    text: option.isObject ? option.modelData.label : String(option.modelData)
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: option.current ? Appearance.accentContrastColor : Appearance.fgColor
                }

                MouseArea {
                    id: optionArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(option.itemValue)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animFast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.easeFade
                    }
                }
            }
        }
    }
}
