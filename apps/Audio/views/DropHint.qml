import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shown over the window while files are dragged onto it.
Rectangle {
    color: Qt.alpha(Appearance.bgColor, 0.85)

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            icon: "library_add"
            font.pixelSize: 56
            color: Appearance.accentColor
        }

        StyledText {
            text: "Drop to play"
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }
}
