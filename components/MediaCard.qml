import "../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets

// Now-playing card, hidden when no MPRIS player is available.
Rectangle {
    id: root

    readonly property var player: {
        const list = Mpris.players.values;
        const playing = list.find(p => p.isPlaying);
        return playing || list[0] || null;
    }

    visible: player !== null
    implicitHeight: 92
    radius: 24
    color: Appearance.surfaceColor

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
