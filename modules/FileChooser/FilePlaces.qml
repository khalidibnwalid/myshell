import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts

// The places sidebar of the file chooser. One Tab stop: the arrows move inside it, Enter or Space opens the
// place under the ring.
Item {
    id: root

    // [{ name, path, icon }]
    property var places: []
    // the folder that is open, its place is marked
    property string folder
    property int placeIndex: -1

    signal chose(string path)

    // a nested layout fills by default, which would squeeze the file list out
    Layout.fillWidth: false
    Layout.preferredWidth: 170
    Layout.maximumWidth: 170
    Layout.alignment: Qt.AlignTop
    implicitHeight: column.implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.List
    Accessible.name: "Places"
    onActiveFocusChanged: {
        if (activeFocus && placeIndex < 0)
            placeIndex = Math.max(0, places.findIndex(p => p.path === folder));
    }
    Keys.onShortcutOverride: event => {
        if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Home, Qt.Key_End, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].indexOf(event.key) >= 0)
            event.accepted = true;
    }
    Keys.onPressed: event => {
        const last = places.length - 1;
        switch (event.key) {
        case Qt.Key_Up:
            placeIndex = Math.max(0, placeIndex - 1);
            break;
        case Qt.Key_Down:
            placeIndex = Math.min(last, placeIndex + 1);
            break;
        case Qt.Key_Home:
            placeIndex = 0;
            break;
        case Qt.Key_End:
            placeIndex = last;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            chose(places[Math.max(0, placeIndex)].path);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 2

        Repeater {
            model: root.places

            Rectangle {
                id: place

                required property var modelData
                required property int index
                readonly property bool current: root.folder === modelData.path

                Layout.fillWidth: true
                implicitHeight: 38
                radius: 19
                color: current ? Qt.alpha(Appearance.accentColor, 0.22) : (area.containsMouse ? Appearance.surfaceColor : "transparent")
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.name
                Accessible.selected: current

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 10

                    MaterialSymbol {
                        icon: place.modelData.icon
                        font.pixelSize: 18
                        color: place.current ? Appearance.accentColor : Appearance.mutedColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: place.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        font.weight: place.current ? Font.DemiBold : Font.Normal
                    }
                }

                FocusRing {
                    gap: 0
                    ringColor: Appearance.fgColor
                    visible: root.activeFocus && root.placeIndex === place.index
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.placeIndex = place.index;
                        root.chose(place.modelData.path);
                    }
                }
            }
        }
    }
}
