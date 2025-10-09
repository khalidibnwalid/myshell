import "../config/"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string text
    property int textSize: 20

    property string icon
    property int iconSize: 24

    property string endIcon
    property int endIconSize: 24

    property int vMargin: 4
    property int hMargin: 18

    property int borderMargin: 6

    property string fillColor: Appearance.accentColor
    property string highlightColor: Appearance.accentColorLight
    property string textColor: Appearance.bgColor
    property string highlightTextColor: Appearance.bgColor

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

        Behavior on color {
            ColorAnimation {
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

        Behavior on opacity {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }
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
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: m => {
            root.hovered(m);
            bg.color = root.highlightColor;
            borderArea.opacity = 0.4;
            root.borderMargin = 8;

            textArea.color = root.highlightTextColor;
            icon.color = root.highlightTextColor;
            endIcon.color = root.highlightTextColor;
        }
        onExited: m => {
            root.unhovered(m);
            root.borderMargin = 6;
            borderArea.opacity = 0.5;
            bg.color = root.fillColor;

            textArea.color = root.textColor;
            icon.color = root.textColor;
            endIcon.color = root.textColor;
        }
        onClicked: m => root.clicked(m)
    }
}
