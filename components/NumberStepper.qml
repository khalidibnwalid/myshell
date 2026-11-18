import "../config/"
import QtQuick
import QtQuick.Layouts

// A small labelled number with − and + buttons; click the number to type one.
// changed(v) is sent with the new value, already limited to from..to (the owner keeps `value`).
// Keyboard: Tab to it, Left/Down and Right/Up change it by one step.
Item {
    id: root

    property string label
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string suffix: ""
    property int fieldWidth: 54

    signal changed(real v)

    function nudge(n) {
        const v = Math.max(from, Math.min(to, Math.round((value + n * step) / step) * step));
        changed(Number(v.toFixed(Math.max(decimals, 4))));
    }

    activeFocusOnTab: true
    implicitHeight: 32
    implicitWidth: row.implicitWidth
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            nudge(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) {
            nudge(1);
            event.accepted = true;
        }
    }
    Keys.onShortcutOverride: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down)
            event.accepted = true;
    }

    RowLayout {
        id: row

        anchors.fill: parent
        spacing: 4

        StyledText {
            visible: root.label !== ""
            text: root.label
            font.pixelSize: 12
            color: Appearance.mutedColor
            Layout.rightMargin: 2
        }

        IconButton {
            icon: "remove"
            size: 26
            iconSize: 16
            activeFocusOnTab: false
            onClicked: root.nudge(-1)
        }

        Rectangle {
            Layout.preferredWidth: root.fieldWidth
            Layout.preferredHeight: 28
            radius: 14
            color: input.activeFocus ? Appearance.surfaceHighColor : Appearance.surfaceColor

            FocusRing {
                visible: root.activeFocus && !input.activeFocus
            }

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Appearance.fgColor
                font.family: Appearance.fontFamily
                font.pixelSize: 13
                selectByMouse: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                text: root.value.toFixed(root.decimals) + root.suffix
                onActiveFocusChanged: {
                    if (activeFocus) {
                        text = root.value.toFixed(root.decimals);
                        selectAll();
                    } else {
                        text = Qt.binding(() => root.value.toFixed(root.decimals) + root.suffix);
                    }
                }
                onAccepted: {
                    const v = parseFloat(text);
                    if (!isNaN(v))
                        root.changed(Math.max(root.from, Math.min(root.to, v)));
                    root.forceActiveFocus();
                }
                Keys.onEscapePressed: root.forceActiveFocus()
            }
        }

        IconButton {
            icon: "add"
            size: 26
            iconSize: 16
            activeFocusOnTab: false
            onClicked: root.nudge(1)
        }
    }
}
