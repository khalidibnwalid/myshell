import "../config/"
import QtQuick
import QtQuick.Layouts

// The shell's dialog look, the same shape as the Quick Settings panel: a rounded glass panel (36 = 20 + 16
// padding) with a hairline border, holding a header tile, your content and pill buttons. It only draws the
// panel. Put it in a window yourself and centre it (`anchors.centerIn: parent`); for the glass to blur, the
// window's layer namespace needs a blur rule in Hyprland (see the quickshell-glass-dialogs skill).
//
//   GlassDialog {
//       anchors.centerIn: parent
//       icon: "lock"; title: "Authentication required"; message: "..."
//       buttons: [{ text: "Cancel", key: "cancel" }, { text: "OK", key: "ok", primary: true, enabled: ready }]
//       onButtonClicked: key => ...
//       FieldInput { Layout.fillWidth: true }     // anything else goes between the header and the buttons
//   }
//
// Escape sends "cancel". shake() nudges the panel sideways (a wrong password).
Rectangle {
    id: root

    // header tile: badge symbol, title and a muted message; with no title the header is left out
    property string icon: "info"
    property string title
    property string message
    property int dialogWidth: 380
    // [{ text, key, primary, enabled }]; none = no button row
    property var buttons: []
    default property alias content: body.data

    signal buttonClicked(string key)

    function shake() {
        shakeAnimation.restart();
    }

    width: dialogWidth
    height: column.implicitHeight + 32
    // outer radius = inner radius (20) + padding (16), like Quick Settings
    radius: 36
    // never more than 15% see-through, whatever the bar opacity is
    color: Qt.alpha(Appearance.bgColor, Math.max(0.35, Appearance.panelAlpha))
    border.color: Appearance.hairlineColor
    border.width: 1
    opacity: 0
    scale: 0.96
    Component.onCompleted: {
        opacity = 1;
        scale = 1;
    }
    Keys.onEscapePressed: root.buttonClicked("cancel")

    transform: Translate {
        id: nudge
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animNormal
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.easeOut
        }
    }

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation {
            target: nudge
            property: "x"
            to: -10
            duration: 50
        }

        NumberAnimation {
            target: nudge
            property: "x"
            to: 10
            duration: 80
        }

        NumberAnimation {
            target: nudge
            property: "x"
            to: 0
            duration: 50
        }
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            visible: root.title !== ""
            implicitHeight: header.implicitHeight + 24
            radius: 20
            color: Appearance.surfaceColor

            RowLayout {
                id: header

                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                Rectangle {
                    visible: root.icon !== ""
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: 24
                    color: Appearance.accentColor

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: root.icon
                        font.pixelSize: 24
                        color: Appearance.accentContrastColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: root.title
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.message
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // your content: stacked with the same 10px gap
        ColumnLayout {
            id: body

            Layout.fillWidth: true
            visible: visibleChildren.length > 0
            spacing: 10
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.buttons.length > 0
            spacing: 8

            Repeater {
                model: root.buttons

                PillButton {
                    required property var modelData

                    Layout.fillWidth: true
                    text: modelData.text
                    toggled: modelData.primary === true
                    enabled: modelData.enabled !== false
                    onClicked: root.buttonClicked(modelData.key)
                }
            }
        }
    }
}
