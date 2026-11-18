import "../config/"
import QtQuick
import QtQuick.Layouts

// Text field in a pill. `value` is what the owner holds; committed() fires when
// the user finishes editing (Enter or focus loss) with a different text.
Rectangle {
    id: root

    property string value
    property string placeholder
    property string icon
    property bool password: false
    // emit edited() on every keystroke (search boxes)
    readonly property alias text: input.text
    readonly property alias inputItem: input

    // true while the text holds keystrokes the user typed and the owner has not taken yet
    property bool dirty: false

    signal committed(string text)
    signal edited(string text)
    signal accepted()

    function clear() {
        input.text = "";
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    // a character typed elsewhere in the window: focus the field and add it
    function append(text) {
        input.forceActiveFocus();
        input.text = input.text + text;
        input.cursorPosition = input.text.length;
        dirty = true;
        edited(input.text);
    }

    function selectAll() {
        input.selectAll();
    }

    // show the value again, e.g. after a typed text was rejected or rounded
    function reset() {
        dirty = false;
        input.text = root.value;
    }

    implicitWidth: 220
    implicitHeight: 36
    radius: height / 2
    color: Appearance.surfaceColor
    border.width: input.activeFocus ? 1 : 0
    border.color: Appearance.accentColor
    opacity: enabled ? 1 : 0.45
    onValueChanged: {
        if (!dirty && input.text !== value)
            input.text = value;
    }
    Component.onCompleted: input.text = value

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        MaterialSymbol {
            visible: root.icon !== ""
            icon: root.icon
            font.pixelSize: 18
            color: Appearance.mutedColor
        }

        TextInput {
            id: input

            inputMethodHints: Qt.ImhSensitiveData // no word autocomplete in these fields

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            clip: true
            color: Appearance.fgColor
            selectionColor: Appearance.accentColor
            selectedTextColor: Appearance.accentContrastColor
            font.family: Appearance.fontFamily
            font.pixelSize: 13
            selectByMouse: true
            // Tab moves on to the next field
            activeFocusOnTab: true
            echoMode: root.password ? TextInput.Password : TextInput.Normal
            onTextEdited: {
                root.dirty = true;
                root.edited(text);
            }
            onAccepted: root.accepted()
            onEditingFinished: {
                // untouched text is never committed: it may be stale
                const typed = root.dirty;
                root.dirty = false;
                if (typed && text !== root.value)
                    root.committed(text);
                else if (text !== root.value)
                    input.text = root.value;
            }

            StyledText {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: root.placeholder
                elide: Text.ElideRight
                color: Appearance.mutedColor
                font.pixelSize: 13
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.IBeamCursor
    }
}
