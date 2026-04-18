import "../config/"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string text
    property int textSize: 16
    property string icon
    property int iconSize: 22
    property real iconFill
    property string image
    property int imageSize: 22
    property string endIcon
    property int endIconSize: 20
    property real endIconFill
    property int vMargin: 4
    property int hMargin: 16
    property int borderMargin: 4
    property color fillColor: Appearance.accentColor
    property color highlightColor: Appearance.accentColorLight
    property color textColor: Appearance.fgColor
    property color highlightTextColor: Appearance.fgColor
    property color borderColor: fillColor
    property real backgroundOpacity: 1
    property alias elide: textArea.elide
    property alias wrapMode: textArea.wrapMode

    signal clicked(var event)
    signal hovered(var event)
    signal unhovered(var event)

    color: "transparent"
    radius: 18
    Layout.preferredWidth: 200
    Layout.preferredHeight: 52
    states: [
        State {
            name: "hovered"
            when: mouseArea.containsMouse

            PropertyChanges {
                target: bg
                color: root.highlightColor
                opacity: Math.max(0.2, root.backgroundOpacity)
            }

            PropertyChanges {
                target: borderArea
                opacity: 1
            }

            PropertyChanges {
                target: root
                borderMargin: 6
            }

            PropertyChanges {
                target: textArea
                color: root.highlightTextColor
            }

            PropertyChanges {
                target: icon
                color: root.highlightTextColor
            }

            PropertyChanges {
                target: endIcon
                color: root.highlightTextColor
            }

        }
    ]
    transitions: [
        Transition {
            ParallelAnimation {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutBack
                }

            }

        }
    ]

    // background (The "Pill" fill)
    Rectangle {
        id: bg

        anchors.centerIn: parent
        width: parent.width - borderMargin * 2
        height: parent.height - borderMargin * 2
        color: root.fillColor
        opacity: root.backgroundOpacity
        radius: root.radius - root.borderMargin
        z: 0
    }

    // border (The "Thin Blue Border" from the volume bar)
    Rectangle {
        id: borderArea

        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        color: "transparent"
        border.color: root.borderColor
        border.width: 1
        radius: root.radius
        opacity: 0.6
        z: 1

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

    }

    // content
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.hMargin
        anchors.rightMargin: root.hMargin
        spacing: 10
        z: 2

        MaterialSymbol {
            id: icon

            icon: root.icon
            font.pixelSize: root.iconSize
            color: root.textColor
            visible: root.icon !== ""
            fill: root.iconFill
        }

        Image {
            id: imageIcon

            visible: root.image !== ""
            source: root.image
            fillMode: Image.PreserveAspectFit
            Layout.preferredWidth: root.imageSize
            Layout.preferredHeight: root.imageSize
        }

        Text {
            id: textArea

            text: root.text
            Layout.fillWidth: true
            color: root.textColor
            font.pixelSize: root.textSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        MaterialSymbol {
            id: endIcon

            icon: root.endIcon
            font.pixelSize: root.endIconSize
            color: root.textColor
            visible: root.endIcon !== ""
            fill: root.endIconFill
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: (m) => {
            return root.clicked(m);
        }
        onEntered: (m) => {
            return root.hovered(m);
        }
        onExited: (m) => {
            return root.unhovered(m);
        }
    }

}
