import "../../config/"
import "../../components/"
import QtQuick
import Quickshell.Widgets

// A file's picture in the file chooser: the image itself, scaled down while it is decoded, or else a symbol
// for its type. Folders get the accent folder symbol.
Item {
    id: root

    property string path
    property string icon: "draft"
    property bool image: false
    property bool dir: false
    property int size: 30

    implicitWidth: size
    implicitHeight: size

    function url(p) {
        return "file://" + p.split("/").map(encodeURIComponent).join("/");
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Math.max(6, root.size / 8)
        color: Appearance.surfaceHighColor
        visible: picture.status === Image.Ready

        Image {
            id: picture

            anchors.fill: parent
            // decoded at twice the size, not at the photo's size: a folder of 20 MP pictures stays light
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            source: root.image && !root.dir ? root.url(root.path) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        icon: root.dir ? "folder" : root.icon
        fill: root.dir ? 1 : 0
        font.pixelSize: Math.round(root.size * 0.68)
        color: root.dir ? Appearance.accentColor : Appearance.mutedColor
    }
}
