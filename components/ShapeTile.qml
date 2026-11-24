import "../config/"
import QtQuick
import QtQuick.Controls

// One square button showing a workspace shape (and the workspace number under it, if any).
Rectangle {
    id: tile

    property string shape: "dot"
    property string label: ""
    property string tip: ""
    property bool selected: false

    signal clicked()

    property int tileSize: 44
    property int glyph: 18

    width: tileSize
    height: tileSize
    radius: tileSize / 3
    activeFocusOnTab: true
    color: selected ? Qt.alpha(Appearance.accentColor, 0.2) : (tileArea.containsMouse ? Appearance.surfaceHighColor : Qt.alpha(Appearance.fgColor, 0.05))
    border.width: selected ? 1.5 : 0
    border.color: Appearance.accentColor
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            tile.clicked();
            event.accepted = true;
        }
    }
    Keys.onShortcutOverride: event => {
        if (event.key === Qt.Key_Space)
            event.accepted = true;
    }

    WorkspaceShape {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: tile.label !== "" ? -5 : 0
        size: tile.glyph
        shape: tile.shape
        filled: true
        fillColor: tile.selected ? Appearance.accentColor : Appearance.fgColor
    }

    StyledText {
        visible: tile.label !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: tile.label
        font.pixelSize: 11
        color: Appearance.mutedColor
    }

    FocusRing {
        radius: tile.radius
    }

    MouseArea {
        id: tileArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }

    ToolTip.visible: tip !== "" && tileArea.containsMouse
    ToolTip.text: tip
}
