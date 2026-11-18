import "../../../config"
import "../../../components"
import ".."
import QtQuick

// A cover picture with a note symbol until (or instead of) the picture
Rectangle {
    id: root

    property string source: ""
    property int symbolSize: Math.max(16, Math.min(width, height) * 0.4)
    property string icon: "music_note"
    readonly property bool ready: art.status === Image.Ready

    color: Appearance.surfaceHighColor
    radius: 10
    clip: true

    MaterialSymbol {
        anchors.centerIn: parent
        visible: !root.ready
        icon: root.icon
        font.pixelSize: root.symbolSize
        color: Appearance.mutedColor
    }

    Image {
        id: art

        anchors.fill: parent
        source: root.source !== "" ? Library.url(root.source) : ""
        sourceSize: Qt.size(Math.max(64, root.width * 2), Math.max(64, root.height * 2))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animNormal
            }
        }
    }
}
