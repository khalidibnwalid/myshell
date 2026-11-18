import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The controls at the bottom: the track, shuffle / previous / play / next / repeat, the position,
// speed, the sleep timer, the volume, and the buttons for the lyrics and the queue.
Rectangle {
    id: root

    // the pane that is open on the right (the buttons at the end show it)
    property string pane: ""

    signal paneToggled(string pane)

    Layout.fillWidth: true
    implicitHeight: 92
    radius: 24
    color: Appearance.surfaceColor

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 18
        spacing: 16

        RowLayout {
            Layout.preferredWidth: 270
            Layout.maximumWidth: 270
            spacing: 12

            Cover {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                radius: 14
                source: Player.track ? Player.track.cover : ""

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.paneToggled("lyrics")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: Player.track ? Player.track.title : "Nothing is playing"
                    elide: Text.ElideRight
                    font.weight: Font.Bold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Player.error !== "" ? "Cannot play this file" : (Player.track ? (Player.track.artist || "Unknown artist") : "Pick a track")
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: Player.error !== "" ? Qt.rgba(1, 0.45, 0.45, 1) : Appearance.mutedColor
                }
            }

            IconButton {
                visible: Player.hasTrack
                readonly property bool fav: Player.hasTrack && Library.favorites[Player.currentPath] === true

                icon: "favorite"
                iconFill: fav ? 1 : 0
                toggled: fav
                size: 34
                iconSize: 20
                onClicked: Library.toggleFavorite(Player.currentPath)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                IconButton {
                    icon: "shuffle"
                    toggled: Player.shuffle
                    size: 38
                    iconSize: 20
                    onClicked: Player.setShuffle(!Player.shuffle)
                }

                IconButton {
                    icon: "skip_previous"
                    iconFill: 1
                    size: 40
                    iconSize: 26
                    onClicked: Player.previous()
                }

                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: 26
                    color: playArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor
                    scale: playArea.pressed ? 0.94 : 1
                    opacity: Player.hasTrack ? 1 : 0.5

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: Player.playing ? "pause" : "play_arrow"
                        fill: 1
                        font.pixelSize: 32
                        color: Appearance.accentContrastColor
                    }

                    MouseArea {
                        id: playArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Player.toggle()
                    }
                }

                IconButton {
                    icon: "skip_next"
                    iconFill: 1
                    size: 40
                    iconSize: 26
                    onClicked: Player.next()
                }

                IconButton {
                    icon: Player.repeat === "one" ? "repeat_one" : "repeat"
                    toggled: Player.repeat !== "off"
                    size: 38
                    iconSize: 20
                    onClicked: Player.cycleRepeat()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledText {
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignRight
                    text: Library.format((seek.dragging ? seek.dragValue * Player.durationMs : Player.positionMs) / 1000)
                    font.pixelSize: 12
                    color: Appearance.mutedColor
                }

                AudioSlider {
                    id: seek

                    Layout.fillWidth: true
                    value: Player.durationMs > 0 ? Player.positionMs / Player.durationMs : 0
                    onCommitted: v => Player.seek(v * Player.durationMs)
                }

                StyledText {
                    Layout.preferredWidth: 44
                    text: Library.format(Player.durationMs / 1000)
                    font.pixelSize: 12
                    color: Appearance.mutedColor
                }
            }
        }

        RowLayout {
            Layout.preferredWidth: 300
            Layout.maximumWidth: 300
            spacing: 6

            PillButton {
                text: Player.speed + "×"
                toggled: Player.speed !== 1
                onClicked: {
                    const steps = [0.75, 1, 1.25, 1.5, 2];
                    const at = steps.indexOf(Player.speed);
                    Player.setSpeed(steps[(at + 1) % steps.length]);
                }
            }

            Dropdown {
                icon: "bedtime"
                caption: Player.sleeping ? Player.sleepLabel : ""
                placeholder: ""
                popupWidth: 170
                model: [
                    {
                        "label": "Sleep timer off",
                        "value": 0
                    },
                    {
                        "label": "15 minutes",
                        "value": 15
                    },
                    {
                        "label": "30 minutes",
                        "value": 30
                    },
                    {
                        "label": "45 minutes",
                        "value": 45
                    },
                    {
                        "label": "1 hour",
                        "value": 60
                    },
                    {
                        "label": "End of this track",
                        "value": -1
                    }
                ]
                onSelected: v => Player.setSleep(v)
            }

            IconButton {
                icon: Player.muted || Player.volume === 0 ? "volume_off" : (Player.volume < 0.4 ? "volume_down" : "volume_up")
                size: 34
                iconSize: 20
                onClicked: {
                    Player.muted = !Player.muted;
                    Player.save();
                }
            }

            AudioSlider {
                Layout.fillWidth: true
                value: Player.muted ? 0 : Player.volume
                onMoved: v => Player.setVolume(v)
                onCommitted: v => Player.setVolume(v)
            }
        }

        RowLayout {
            spacing: 0

            IconButton {
                icon: "lyrics"
                toggled: root.pane === "lyrics"
                size: 38
                iconSize: 22
                onClicked: root.paneToggled("lyrics")
            }

            IconButton {
                icon: "queue_music"
                toggled: root.pane === "queue"
                size: 38
                iconSize: 22
                onClicked: root.paneToggled("queue")
            }
        }
    }
}
