import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// The autocomplete popup: the suggestions for the word being typed, under the
// pointer or in the corner of the focused window. (Next to the text cursor it is
// drawn by the input method helper instead: see services/Autocomplete.qml.) It never takes the keyboard;
// Tab and Escape reach it through the input method helper. A click picks a word.
PanelWindow {
    id: root

    readonly property int edgeGap: 8
    // the screen the anchor point is on
    readonly property var targetScreen: {
        for (const s of Quickshell.screens) {
            if (Autocomplete.anchorX >= s.x && Autocomplete.anchorX < s.x + s.width && Autocomplete.anchorY >= s.y && Autocomplete.anchorY < s.y + s.height)
                return s;
        }
        return Quickshell.screens[0];
    }
    readonly property real wantedLeft: Autocomplete.anchorX - (targetScreen?.x ?? 0)
    readonly property real wantedTop: (Autocomplete.anchorAbove ? Autocomplete.anchorY - implicitHeight : Autocomplete.anchorY) - (targetScreen?.y ?? 0)

    screen: targetScreen
    // with the "text cursor" placement the helper draws the list instead
    visible: Autocomplete.visible && !Autocomplete.drawnByHelper && Autocomplete.suggestions.length > 0
    color: "transparent"
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
    }

    // at the anchor point, pushed back in if it would leave the screen
    margins.left: Math.max(edgeGap, Math.min(wantedLeft, (targetScreen?.width ?? 0) - implicitWidth - edgeGap))
    margins.top: Math.max(edgeGap, Math.min(wantedTop, (targetScreen?.height ?? 0) - implicitHeight - edgeGap))

    Rectangle {
        id: card

        anchors.fill: parent
        implicitWidth: Math.max(170, list.implicitWidth + 12)
        implicitHeight: list.implicitHeight + 12
        radius: 18
        // more solid than a panel, so the words read on any background
        color: Qt.alpha(Appearance.bgColor, Math.max(0.86, Appearance.panelAlpha))
        border.width: 1
        border.color: Appearance.outlineColor

        ColumnLayout {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: Autocomplete.suggestions

                delegate: Rectangle {
                    id: row

                    required property string modelData
                    required property int index
                    readonly property bool current: index === Autocomplete.index
                    readonly property color contentColor: current ? Appearance.accentContrastColor : Appearance.fgColor

                    Layout.fillWidth: true
                    implicitWidth: word.implicitWidth + 28
                    implicitHeight: 34
                    radius: 12
                    color: current ? Appearance.accentColor : (rowArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

                    // what was typed in regular weight, the rest of the word in bold
                    StyledText {
                        id: word

                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Autocomplete.rightToLeft ? Text.AlignRight : Text.AlignLeft
                        textFormat: Text.StyledText
                        text: row.modelData.substring(0, Autocomplete.prefix.length) + "<b>" + row.modelData.substring(Autocomplete.prefix.length) + "</b>"
                        color: row.contentColor
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Autocomplete.choose(row.index)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                text: "Tab  next   ·   Esc  close"
                color: Appearance.mutedColor
                font.pixelSize: 11
            }
        }
    }
}
