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
    // a slim one-line header and buttons that keep their own width (for big dialogs like the file chooser)
    property bool compact: false
    // [{ text, key, primary, enabled }]; none = no button row
    property var buttons: []
    default property alias content: body.data
    // extra controls on the left of the button row (compact dialogs)
    property alias footer: footerRow.data

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
            implicitHeight: header.implicitHeight + (root.compact ? 16 : 24)
            radius: root.compact ? 18 : 20
            color: Appearance.surfaceColor

            RowLayout {
                id: header

                anchors.fill: parent
                anchors.margins: root.compact ? 8 : 12
                spacing: root.compact ? 12 : 14

                Rectangle {
                    visible: root.icon !== ""
                    implicitWidth: root.compact ? 34 : 48
                    implicitHeight: root.compact ? 34 : 48
                    radius: implicitWidth / 2
                    color: Appearance.accentColor

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: root.icon
                        font.pixelSize: root.compact ? 18 : 24
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
                        visible: text !== "" && !root.compact
                        text: root.message
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                // compact: the message sits at the right end of the same line
                StyledText {
                    Layout.maximumWidth: 280
                    visible: root.compact && text !== ""
                    text: root.message
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    elide: Text.ElideRight
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

            RowLayout {
                id: footerRow

                spacing: 8
            }

            Item {
                Layout.fillWidth: true
                visible: root.compact
            }

            Repeater {
                model: root.buttons

                PillButton {
                    required property var modelData

                    Layout.fillWidth: !root.compact
                    Layout.preferredWidth: root.compact ? 120 : -1
                    text: modelData.text
                    toggled: modelData.primary === true
                    enabled: modelData.enabled !== false
                    onClicked: root.buttonClicked(modelData.key)
                }
            }
        }
    }
}
