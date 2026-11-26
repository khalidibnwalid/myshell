import "../config/"
import QtQuick
import QtQuick.Layouts

// Small text pill: surface by default, accent when toggled
Rectangle {
    id: root

    property string text
    property string icon
    property bool toggled: false
    readonly property color contentColor: toggled ? Appearance.accentContrastColor : Appearance.fgColor

    signal clicked()

    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }
    // Space is the player's play key in some windows: a focused button keeps it
    Keys.onShortcutOverride: event => {
        if (event.key === Qt.Key_Space)
            event.accepted = true;
    }
    implicitHeight: 36
    implicitWidth: row.implicitWidth + 32
    radius: height / 2
    color: toggled ? (mouseArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor) : (mouseArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor)
    scale: mouseArea.pressed ? 0.96 : 1
    opacity: enabled ? 1 : 0.45

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 8

        MaterialSymbol {
            visible: root.icon !== ""
            icon: root.icon
            font.pixelSize: 18
            color: root.contentColor
        }

        StyledText {
            text: root.text
            font.pixelSize: 13
            font.weight: Font.Medium
            color: root.contentColor
        }
    }

    FocusRing {
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
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
