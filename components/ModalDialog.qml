import "../config/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A centred dialog with a title, your content, and buttons. Needs to live inside an ApplicationWindow.
// buttons: [{ text, key, primary }]; buttonClicked(key) closes it too. Escape or a click outside sends
// "cancel". Enter presses the primary button.
Popup {
    id: root

    property string title
    property var buttons: [
        {
            "text": "Cancel",
            "key": "cancel"
        },
        {
            "text": "OK",
            "key": "ok",
            "primary": true
        }
    ]
    default property alias content: body.data
    property int dialogWidth: 360

    signal buttonClicked(string key)

    function press(key) {
        close();
        buttonClicked(key);
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    width: dialogWidth
    padding: 18
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onClosed: if (!_pressed)
        buttonClicked("cancel")
    onOpened: _pressed = false

    property bool _pressed: false

    Overlay.modal: Rectangle {
        color: Qt.alpha("black", 0.35)
    }

    background: Rectangle {
        radius: 24
        color: Qt.tint(Appearance.bgColor, Qt.alpha(Appearance.fgColor, 0.1))
        border.width: 1
        border.color: Appearance.outlineColor
    }

    contentItem: ColumnLayout {
        spacing: 14
        Keys.onReturnPressed: {
            const p = root.buttons.find(b => b.primary);
            if (p)
                root.chose(p.key);
        }
        Keys.onEnterPressed: Keys.returnPressed(event)

        StyledText {
            text: root.title
            font.pixelSize: 17
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            spacing: 10
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Repeater {
                model: root.buttons

                PillButton {
                    required property var modelData

                    text: modelData.text
                    toggled: modelData.primary === true
                    onClicked: root.chose(modelData.key)
                }
            }
        }
    }

    function chose(key) {
        _pressed = true;
        close();
        buttonClicked(key);
    }
}
