import "../config/"
import QtQuick
import QtQuick.Layouts

// Large square-ish button with a big icon: accent filled when on.
Rectangle {
    id: root

    property string icon
    property string title
    property string subtitle
    property bool toggled: false
    property bool danger: false
    readonly property color contentColor: toggled ? Appearance.accentContrastColor : Appearance.fgColor

    signal clicked()

    implicitHeight: 112
    implicitWidth: 140
    radius: 26
    color: toggled ? (area.containsMouse ? Appearance.accentColorLight : Appearance.accentColor) : (area.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor)
    scale: area.pressed ? 0.97 : 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 2

        MaterialSymbol {
            icon: root.icon
            fill: root.toggled ? 1 : 0
            font.pixelSize: 30
            color: root.danger && !root.toggled ? "#f2b8b5" : root.contentColor
        }

        Item {
            Layout.fillHeight: true
        }

        StyledText {
            Layout.fillWidth: true
            text: root.title
            elide: Text.ElideRight
            font.weight: Font.DemiBold
            color: root.contentColor
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.subtitle
            elide: Text.ElideRight
            font.pixelSize: 12
            color: root.contentColor
            opacity: 0.7
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.easeFade
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.easeStandard
        }
    }
}
