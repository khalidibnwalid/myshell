import "../../../components"
import "../../../config"
import QtQuick

// Round colour preview; click it to open a colour picker.
Rectangle {
    id: well

    signal clicked()

    implicitWidth: 30
    implicitHeight: 30
    radius: 15
    border.width: 1
    border.color: Appearance.outlineColor
    scale: wellArea.pressed ? 0.9 : (wellArea.containsMouse ? 1.1 : 1)

    MaterialSymbol {
        anchors.centerIn: parent
        icon: "palette"
        font.pixelSize: 16
        // readable on both light and dark colours
        color: well.color.hslLightness > 0.55 ? "#1b1b1f" : "#f2f2f5"
        opacity: wellArea.containsMouse ? 1 : 0.7
    }

    MouseArea {
        id: wellArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: well.clicked()
    }

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animFast
            easing.type: Easing.OutCubic
        }
    }
}
