import "../../components"
import "../../config"
import "../../services" as Services
import QtQuick
import Quickshell.Widgets

// A tool's own icon, or its symbol in a soft circle when the icon theme has none.
Item {
    id: face

    property string backend: Services.Agent.backend
    property int size: 28
    property bool failed: false
    readonly property string image: Services.Agent.icons[backend] || ""
    readonly property bool outlined: Services.Agent.outlined.indexOf(backend) >= 0

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: face.image === "" || face.failed
        color: Qt.alpha(face.failed ? "#ff5f5f" : Appearance.accentColor, 0.18)

        MaterialSymbol {
            anchors.centerIn: parent
            icon: face.failed ? "error" : (Services.Agent.symbols[face.backend] || "auto_awesome")
            fill: 1
            font.pixelSize: face.size * 0.55
            color: face.failed ? "#ff5f5f" : Appearance.accentColor
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: width * 0.28
        visible: face.image !== "" && !face.failed
        color: face.outlined ? "#1b2125" : "transparent"

        Image {
            anchors.fill: parent
            anchors.margins: face.outlined ? face.size * 0.16 : 0
            source: face.image
            sourceSize: Qt.size(face.size * 2, face.size * 2)
            fillMode: Image.PreserveAspectFit
        }
    }
}
