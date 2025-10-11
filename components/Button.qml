import "../config/"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string text
    property int textSize: 20

    property string icon
    property int iconSize: 24
    property real iconFill

    property string image
    property int imageSize: 24

    property string endIcon
    property int endIconSize: 24
    property real endIconFill

    property int vMargin: 4
    property int hMargin: 18

    property int borderMargin: 6

    property string fillColor: Appearance.accentColor
    property string highlightColor: Appearance.accentColorLight
    property string textColor: Appearance.bgColor
    property string highlightTextColor: Appearance.bgColor

    property alias elide: textArea.elide
    property alias wrapMode: textArea.wrapMode

    signal clicked(var event)
    signal hovered(var event)
    signal unhovered(var event)

    color: "transparent"
    radius: 16
    Layout.preferredWidth: 200
    Layout.preferredHeight: 60

    // background
    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: parent.width - borderMargin * 2
        height: parent.height - borderMargin * 2
        color: root.fillColor
        radius: 16
        z: 0

        Behavior on width {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }
    }

    // border
    Rectangle {
        id: borderArea
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        color: "transparent"
        border.color: root.fillColor
        border.width: 3
        radius: 16 + borderMargin
        opacity: 0.5
        z: 1
    }

    // content
    RowLayout {
        anchors.fill: parent
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.hMargin
        anchors.rightMargin: root.hMargin
        anchors.topMargin: root.vMargin
        anchors.bottomMargin: root.vMargin
        spacing: 8
        z: 2

        MaterialSymbol {
            id: icon
            icon: root.icon
            font.pixelSize: root.iconSize
            color: root.textColor
            Layout.alignment: Qt.AlignVCenter
            visible: root.icon !== ""
            fill: root.iconFill
        }

        Image {
            id: imageIcon
            visible: root.image !== ""
            source: root.image
            fillMode: Image.PreserveAspectFit
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.imageSize
            Layout.preferredHeight: root.imageSize
        }

        Text {
            id: textArea
            text: root.text
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            color: root.textColor
            font.pixelSize: root.textSize
            font.weight: Font.DemiBold
            z: 2
        }

        MaterialSymbol {
            id: endIcon
            icon: root.endIcon
            font.pixelSize: root.endIconSize
            color: root.textColor
            Layout.alignment: Qt.AlignVCenter
            visible: root.endIcon !== ""
            fill: root.endIconFill
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: m => root.hovered(m)
        onExited: m => root.unhovered(m)
        onClicked: m => root.clicked(m)
    }

    states: [
        State {
            name: "hovered"
            when: mouseArea.containsMouse
            PropertyChanges {
                target: bg
                color: root.highlightColor
            }
            PropertyChanges {
                target: borderArea
                opacity: 0.4
            }
            PropertyChanges {
                target: root
                borderMargin: 8
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
                    duration: 100
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            }
        }
    ]
}
