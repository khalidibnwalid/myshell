import "../../components"
import "../../config"
import "../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

// One notification. Used as a floating toast and as a row of the notification panel.
Rectangle {
    id: root

    property var notification // live notification object, may be null
    property string summary
    property string body
    property string appName
    property string appIcon
    property string image
    property string meta // text after the title: age or app name
    property bool inPanel: false
    property bool first: true
    property bool last: true
    property bool expanded: false
    property int cornerRadius: 24
    readonly property string avatarSource: NotificationService.iconSource(image || appIcon)
    readonly property var actions: expanded && notification ? notification.actions : []

    signal closeRequested()
    signal bodyClicked()

    implicitHeight: content.implicitHeight + 28
    color: inPanel ? (hover.hovered ? Appearance.surfaceHighColor : Appearance.surfaceColor) : Appearance.panelColor
    border.width: inPanel ? 0 : 1
    border.color: Appearance.hairlineColor
    topLeftRadius: first ? cornerRadius : 6
    topRightRadius: first ? cornerRadius : 6
    bottomLeftRadius: last ? cornerRadius : 6
    bottomRightRadius: last ? cornerRadius : 6
    clip: true

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // clicking the body runs the notification's default action, as the spec intends
            const actions = root.notification ? root.notification.actions : [];
            const action = actions.find(a => a.identifier === "default");
            if (action)
                action.invoke();
            root.bodyClicked();
        }
    }

    ColumnLayout {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // avatar: image / app icon, falling back to an initial
            ClippingRectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: Qt.alpha(Appearance.accentColor, 0.16)

                StyledText {
                    anchors.centerIn: parent
                    visible: avatar.status !== Image.Ready
                    text: (root.summary || root.appName || "?").trim().charAt(0).toUpperCase()
                    color: Appearance.accentColor
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                Image {
                    id: avatar

                    anchors.fill: parent
                    anchors.margins: root.image ? 0 : 8
                    source: root.avatarSource
                    sourceSize: Qt.size(96, 96)
                    fillMode: root.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                RowLayout {
                    id: titleRow

                    Layout.fillWidth: true
                    spacing: 5

                    StyledText {
                        Layout.maximumWidth: titleRow.width - metaText.implicitWidth - 5
                        text: root.summary
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        id: metaText

                        visible: root.meta !== ""
                        text: "· " + root.meta
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.body
                    textFormat: Text.PlainText
                    color: Qt.alpha(Appearance.fgColor, 0.82)
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: root.expanded ? 8 : (root.inPanel ? 1 : 2)
                }
            }

            // panel: expand chevron, toast: close
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: btnArea.containsMouse ? Qt.alpha(Appearance.fgColor, 0.2) : Appearance.surfaceHighColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    icon: root.inPanel ? "keyboard_arrow_down" : "close"
                    font.pixelSize: root.inPanel ? 20 : 16
                    color: Appearance.fgColor
                    rotation: root.expanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Appearance.animNormal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.easeStandard
                        }
                    }
                }

                MouseArea {
                    id: btnArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.inPanel ? root.expanded = !root.expanded : root.closeRequested()
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animFast
                    }
                }
            }
        }

        // actions, shown when expanded
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 52
            visible: root.expanded
            spacing: 6

            Repeater {
                model: root.actions

                delegate: PillButton {
                    required property var modelData

                    implicitHeight: 30
                    text: modelData.text
                    onClicked: modelData.invoke()
                }
            }

            PillButton {
                implicitHeight: 30
                text: "Dismiss"
                onClicked: root.closeRequested()
            }
        }
    }

    Behavior on implicitHeight {
        enabled: root.inPanel

        NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.easeStandard
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
        }
    }
}
