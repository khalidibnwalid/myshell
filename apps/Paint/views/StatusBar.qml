import ".."
import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Layouts

// Information only: a hint or message, the cursor, the selection, the size and the zoom.
RowLayout {
    id: root

    property string hint: ""
    property point cursor: Qt.point(-1, -1)
    property real zoom: 1

    signal zoomIn
    signal zoomOut
    signal zoomFit
    signal zoomActual

    spacing: 14

    StyledText {
        Layout.fillWidth: true
        text: PaintDoc.status !== "" ? PaintDoc.status : root.hint
        font.pixelSize: 12
        color: Appearance.mutedColor
        elide: Text.ElideRight
    }

    StyledText {
        visible: PaintDoc.sel !== null
        text: PaintDoc.sel ? "Selection " + (PaintDoc.sel.x1 - PaintDoc.sel.x0) + " × " + (PaintDoc.sel.y1 - PaintDoc.sel.y0) : ""
        font.pixelSize: 12
        color: Appearance.mutedColor
    }

    StyledText {
        text: root.cursor.x >= 0 ? Math.floor(root.cursor.x) + ", " + Math.floor(root.cursor.y) : ""
        font.pixelSize: 12
        color: Appearance.mutedColor
        Layout.preferredWidth: 80
    }

    StyledText {
        text: PaintDoc.docW + " × " + PaintDoc.docH + " px"
        font.pixelSize: 12
        color: Appearance.mutedColor
    }

    RowLayout {
        spacing: 0

        IconButton {
            icon: "zoom_out"
            size: 28
            iconSize: 17
            onClicked: root.zoomOut()
        }

        StyledText {
            text: Math.round(root.zoom * 100) + "%"
            font.pixelSize: 12
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignHCenter
        }

        IconButton {
            icon: "zoom_in"
            size: 28
            iconSize: 17
            onClicked: root.zoomIn()
        }

        IconButton {
            icon: "fit_screen"
            size: 28
            iconSize: 17
            onClicked: root.zoomFit()
        }

        IconButton {
            icon: "pin"
            size: 28
            iconSize: 17
            onClicked: root.zoomActual()
        }
    }
}
