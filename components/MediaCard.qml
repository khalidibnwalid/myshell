import "../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets

// Now-playing card, hidden when no MPRIS player is available.
Rectangle {
    id: root

    property bool seeking: false
    property real seekProgress: 0
    property var selectedPlayer: null

    readonly property var players: Mpris.players.values
    readonly property var player: {
        const list = root.players;
        if (root.selectedPlayer && list.includes(root.selectedPlayer))
            return root.selectedPlayer;
        return list.find(p => p.isPlaying) || list[0] || null;
    }

    visible: player !== null
    implicitHeight: 120
    radius: 24
    color: Appearance.surfaceColor

    readonly property real progress: player && player.length > 0
        ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    function movePlayer(offset) {
        const list = root.players;
        if (list.length < 2)
            return;
        const currentIndex = list.indexOf(root.player);
        root.selectedPlayer = list[(currentIndex + offset + list.length) % list.length];
    }

    FrameAnimation {
        running: root.player !== null && root.player.isPlaying && root.player.positionSupported
        onTriggered: root.player.positionChanged()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        // artwork (falls back to initials)
        ClippingRectangle {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            radius: 10
            color: Appearance.surfaceHighColor

            StyledText {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: (root.player?.trackTitle || "♪").substring(0, 2)
                color: Appearance.fgColor
                font.pixelSize: 20
                font.weight: Font.Bold
            }

            Image {
                id: art

                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(160, 160)
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

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle || "Nothing playing"
                    elide: Text.ElideRight
                    color: Appearance.fgColor
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: chip.text !== ""
                    implicitWidth: chip.implicitWidth + 16
                    implicitHeight: 20
                    radius: 10
                    color: Appearance.surfaceHighColor

                    StyledText {
                        id: chip

                        anchors.centerIn: parent
                        text: root.player?.identity ?? ""
                        color: Appearance.fgColor
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }

                RowLayout {
                    visible: root.players.length > 1
                    spacing: 2

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: previousPlayerArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            icon: "chevron_left"
                            font.pixelSize: 18
                            color: Appearance.fgColor
                        }

                        MouseArea {
                            id: previousPlayerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.movePlayer(-1)
                        }
                    }

                    Repeater {
                        model: root.players

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            Layout.alignment: Qt.AlignVCenter
                            width: index === root.players.indexOf(root.player) ? 7 : 5
                            height: width
                            radius: width / 2
                            color: index === root.players.indexOf(root.player) ? Appearance.accentColor : Appearance.outlineColor

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedPlayer = modelData
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: nextPlayerArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            icon: "chevron_right"
                            font.pixelSize: 18
                            color: Appearance.fgColor
                        }

                        MouseArea {
                            id: nextPlayerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.movePlayer(1)
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || root.player?.trackAlbum || ""
                elide: Text.ElideRight
                color: Appearance.fgColor
                opacity: 0.7
                font.pixelSize: 13
            }

            Item {
                id: seekSlider

                Layout.fillWidth: true
                Layout.preferredHeight: 14
                Layout.topMargin: 6
                visible: root.player !== null && root.player.lengthSupported && root.player.positionSupported
                property real shownProgress: root.seeking ? root.seekProgress : root.progress

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 0
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Appearance.surfaceHighColor

                    Rectangle {
                        width: parent.width * seekSlider.shownProgress
                        height: parent.height
                        radius: parent.radius
                        color: Appearance.accentColor
                    }
                }

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    x: Math.max(0, Math.min(seekSlider.width - width, seekSlider.width * seekSlider.shownProgress - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    color: Appearance.accentColor
                    border.width: 2
                    border.color: Appearance.bgColor
                }

                MouseArea {
                    id: seekArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.player !== null && root.player.canSeek && root.player.positionSupported

                    function updateProgress() {
                        root.seekProgress = Math.max(0, Math.min(1, mouseX / width));
                    }

                    onPressed: {
                        root.seeking = true;
                        updateProgress();
                    }
                    onPositionChanged: if (pressed) updateProgress()
                    onReleased: {
                        if (root.player && root.player.canSeek)
                            root.player.position = root.seekProgress * root.player.length;
                        root.seeking = false;
                    }
                    onCanceled: root.seeking = false
                }
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.leftMargin: -3
                spacing: 16

                Repeater {
                    model: [
                        {
                            "icon": "skip_previous",
                            "action": () => root.player?.previous()
                        },
                        {
                            "icon": root.player?.isPlaying ? "pause" : "play_arrow",
                            "action": () => root.player?.togglePlaying()
                        },
                        {
                            "icon": "skip_next",
                            "action": () => root.player?.next()
                        }
                    ]

                    delegate: MaterialSymbol {
                        required property var modelData

                        icon: modelData.icon
                        font.pixelSize: 24
                        color: Appearance.fgColor
                        opacity: ma.containsMouse ? 1 : 0.8
                        scale: ma.pressed ? 0.85 : 1

                        MouseArea {
                            id: ma

                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.action()
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animFast
                            }
                        }
                    }
                }
            }
        }
    }
}
