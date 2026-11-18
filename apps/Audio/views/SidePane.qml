import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The pane on the right: the lyrics or the queue. It folds away: Layout.preferredWidth follows `pane`.
Item {
    id: root

    // "" when the pane is folded away, else "lyrics" or "queue"
    property string pane: ""

    signal paneSelected(string pane)

    Layout.fillHeight: true
    Layout.preferredWidth: root.pane !== "" ? 340 : 0
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    clip: true

    Behavior on Layout.preferredWidth {
        NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        width: 340
        height: parent.height
        radius: 24
        color: Appearance.surfaceColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Segmented {
                Layout.alignment: Qt.AlignHCenter
                value: root.pane
                model: [
                    {
                        "label": "Lyrics",
                        "value": "lyrics"
                    },
                    {
                        "label": "Queue",
                        "value": "queue"
                    }
                ]
                onSelected: v => root.paneSelected(v)
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.pane === "queue" ? 1 : 0

                // lyrics, or the cover when there are none
            LyricsView {
            }

                // the queue, dragged into order by the handle on the left
            QueueView {
            }
            }
        }
    }
}
