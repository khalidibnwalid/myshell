import "../config/"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property real value: 0
    property string icon: "volume_up"
    property int iconSize: 24
    property int borderMargin: 4
    property string fillColor: Appearance.accentColor
    property string backgroundFillColor: "black"
    property string borderColor: Appearance.accentColor
    property string iconColor: Appearance.bgColor
    property bool vertical: true

    signal dragged(real value)

    implicitWidth: vertical ? 50 : 380
    implicitHeight: vertical ? 200 : 50

    // outer border area
    Rectangle {
        id: borderArea

        anchors.fill: parent
        color: "transparent"
        border.color: root.borderColor
        border.width: 1
        radius: bg.radius + (root.width - bg.width) / 2
        opacity: 0.3
    }

    // background (pill shape)
    Rectangle {
        id: bg

        anchors.centerIn: parent
        width: parent.width - root.borderMargin * 2
        height: parent.height - root.borderMargin * 2
        color: root.backgroundFillColor
        radius: root.vertical ? 12 : 16
        clip: true

        // value fill
        Rectangle {
            id: fillRect

            anchors.bottom: root.vertical ? parent.bottom : parent.bottom
            anchors.left: parent.left
            anchors.top: root.vertical ? undefined : parent.top
            width: root.vertical ? parent.width : parent.width * Math.min(root.value, 1)
            height: root.vertical ? parent.height * Math.min(root.value, 1) : parent.height
            color: root.fillColor
            radius: bg.radius
        }

        // percentage text
        Text {
            anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            anchors.left: root.vertical ? undefined : parent.left
            anchors.leftMargin: root.vertical ? 0 : 45
            anchors.bottomMargin: root.vertical ? 40 : 0
            anchors.bottom: root.vertical ? parent.bottom : undefined
            text: Math.round(Math.min(root.value, 1) * 100)
            color: root.value > (root.vertical ? 0.3 : 0.15) ? root.iconColor : Appearance.fgColor
            font.pixelSize: root.vertical ? 20 : 16
            font.bold: true
            opacity: 0.8
        }

        // contents (icon)
        MaterialSymbol {
            anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            anchors.left: root.vertical ? undefined : parent.left
            anchors.leftMargin: root.vertical ? 0 : 12
            anchors.bottom: root.vertical ? parent.bottom : undefined
            anchors.bottomMargin: root.vertical ? 8 : 0
            icon: root.icon
            font.pixelSize: root.vertical ? 26 : 22
            color: root.value > (root.vertical ? 0.15 : 0.05) ? root.iconColor : Appearance.fgColor
        }

    }

    MouseArea {
        id: mouseArea

        function updateValue() {
            var newValue;
            if (root.vertical)
                newValue = Math.max(0, Math.min(1, 1 - mouseY / height));
            else
                newValue = Math.max(0, Math.min(1, mouseX / width));
            root.dragged(newValue);
        }

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: {
            if (pressed)
                updateValue();

        }
        onClicked: updateValue()
    }

}
