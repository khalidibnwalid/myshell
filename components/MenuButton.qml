import "../config/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A text button that opens a menu of actions (File, Edit…). Needs to live inside an ApplicationWindow.
// model: { label, key, shortcut, icon, enabled } objects; { separator: true } draws a line.
// triggered(key) says which one was chosen. Keyboard: Enter, Space or Down opens it, then Up/Down and Enter.
Rectangle {
    id: root

    property string text
    property var model: []
    property int popupWidth: 240
    readonly property bool opened: popup.opened

    signal triggered(string key)

    activeFocusOnTab: true
    implicitHeight: 32
    implicitWidth: label.implicitWidth + 24
    radius: height / 2
    color: area.containsMouse || popup.opened ? Appearance.surfaceHighColor : "transparent"
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
            popup.open();
            event.accepted = true;
        }
    }
    Keys.onShortcutOverride: event => {
        if (event.key === Qt.Key_Space)
            event.accepted = true;
    }

    FocusRing {
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.opened ? popup.close() : popup.open()
    }

    Popup {
        id: popup

        y: root.height + 6
        width: root.popupWidth
        padding: 6
        margins: 8
        onOpened: list.forceActiveFocus()
        onClosed: root.forceActiveFocus()

        background: Rectangle {
            radius: 18
            color: Qt.tint(Appearance.bgColor, Qt.alpha(Appearance.fgColor, 0.1))
            border.width: 1
            border.color: Appearance.outlineColor
        }

        contentItem: ListView {
            id: list

            implicitHeight: contentHeight
            model: root.model
            clip: true
            interactive: false
            currentIndex: -1
            keyNavigationEnabled: false
            Keys.onPressed: event => {
                const step = event.key === Qt.Key_Down ? 1 : (event.key === Qt.Key_Up ? -1 : 0);
                if (step !== 0) {
                    let i = currentIndex;
                    for (let n = 0; n < count; n++) {
                        i = (i + step + count) % count;
                        const it = root.model[i];
                        if (!it.separator && it.enabled !== false)
                            break;
                    }
                    currentIndex = i;
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && currentIndex >= 0) {
                    root.choose(root.model[currentIndex]);
                    event.accepted = true;
                }
            }

            delegate: Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool sep: modelData.separator === true
                readonly property bool on: modelData.enabled !== false

                width: list.width
                height: sep ? 9 : 34

                Rectangle {
                    visible: row.sep
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    color: Appearance.hairlineColor
                }

                Rectangle {
                    visible: !row.sep
                    anchors.fill: parent
                    radius: 12
                    color: (itemArea.containsMouse || list.currentIndex === row.index) && row.on ? Appearance.surfaceHighColor : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 8
                        opacity: row.on ? 1 : 0.4

                        MaterialSymbol {
                            Layout.preferredWidth: 20
                            icon: row.modelData.icon ?? ""
                            font.pixelSize: 18
                            color: Appearance.fgColor
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.label ?? ""
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: row.modelData.shortcut ?? ""
                            font.pixelSize: 12
                            color: Appearance.mutedColor
                        }
                    }

                    MouseArea {
                        id: itemArea

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: row.on
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choose(row.modelData)
                    }
                }
            }
        }
    }

    function choose(item) {
        popup.close();
        triggered(item.key);
    }
}
