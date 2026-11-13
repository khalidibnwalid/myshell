import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// What the lock screen looks like: blurred wallpaper, a large clock, and the
// password field under the user's picture. All authentication stays in Idle.qml.
Item {
    id: root

    // typed so far (owned by Idle.qml)
    property string password: ""
    // error or progress line; "" shows the PAM prompt instead
    property string statusText: ""
    property string prompt: ""
    property bool inputEnabled: false
    property bool showInput: false
    // true once the compositor confirms the session is locked
    property bool secure: false
    readonly property string userName: Quickshell.env("USER") || "Session"
    readonly property bool failed: statusText !== "" && statusText !== "Checking…"
    // the account picture, if the user has one
    readonly property string facePath: Quickshell.env("HOME") + "/.face"
    property bool hasFace: false
    // the plain "Password:" prompt adds nothing next to the field
    readonly property string shownPrompt: /^\s*password:?\s*$/i.test(prompt) ? "" : prompt

    Process {
        running: true
        command: ["test", "-r", root.facePath]
        onExited: code => root.hasFace = code === 0
    }

    signal edited(string text)
    signal submitted()

    // typing detaches the field from `password`, so clear it by hand
    // when Idle.qml empties the password (submit, failed attempt, new lock)
    onPasswordChanged: {
        if (passwordInput.text !== password)
            passwordInput.text = password;
    }
    onSecureChanged: {
        if (secure)
            passwordInput.forceActiveFocus();
    }
    onFailedChanged: {
        if (failed)
            shake.restart();
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.bgColor
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: Config.appearance.wallpaper ? "file://" + Config.appearance.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
    }

    // soft, slightly zoomed wallpaper so the clock and field read on any picture
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 48
        scale: 1.06
    }

    // tint with the theme's background: lighter at the top, denser behind the field
    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Appearance.bgColor, 0.35)
            }

            GradientStop {
                position: 1
                color: Qt.alpha(Appearance.bgColor, 0.72)
            }
        }
    }

    // everything fades and settles in when the screen locks
    Item {
        id: stage

        anchors.fill: parent
        opacity: root.secure ? 1 : 0
        scale: root.secure ? 1 : 1.03

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animSlow
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animSlow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.easeOut
            }
        }

        // --- clock ---
        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.16)
            spacing: 0

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.format("dddd, d MMMM").toUpperCase()
                color: Appearance.mutedColor
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: 3
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                StyledText {
                    text: Config.bar.clock24h ? Time.format("HH") : Time.format("hh ap").replace(/ ?[ap]m/i, "")
                    font.pixelSize: 132
                    font.weight: Font.Bold
                    font.letterSpacing: -3
                }

                StyledText {
                    text: Time.format("mm")
                    color: Appearance.accentColor
                    font.pixelSize: 132
                    font.weight: Font.Bold
                    font.letterSpacing: -3
                }
            }
        }

        // --- who is signing in, and the password ---
        ColumnLayout {
            id: auth

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(parent.height * 0.14)
            spacing: 0

            ClippingRectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 84
                implicitHeight: 84
                radius: 42
                color: Qt.alpha(Appearance.fgColor, 0.12)
                border.width: 2
                border.color: Qt.alpha(Appearance.fgColor, 0.18)

                // the account picture, when there is one
                Image {
                    id: face

                    anchors.fill: parent
                    source: root.hasFace ? "file://" + root.facePath : ""
                    sourceSize.width: 168
                    sourceSize.height: 168
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: root.userName.charAt(0).toUpperCase()
                    color: Appearance.accentColor
                    font.pixelSize: 34
                    font.weight: Font.Bold
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                text: root.userName
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: field

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 18
                implicitWidth: 340
                implicitHeight: 54
                radius: 27
                color: Qt.alpha(Appearance.fgColor, 0.1)
                border.width: 1.5
                border.color: root.failed ? Appearance.accentColor : (passwordInput.activeFocus ? Qt.alpha(Appearance.fgColor, 0.45) : Qt.alpha(Appearance.fgColor, 0.16))

                // a wrong password shakes the field
                transform: Translate {
                    id: nudge
                }

                SequentialAnimation {
                    id: shake

                    NumberAnimation {
                        target: nudge
                        property: "x"
                        to: -12
                        duration: 50
                    }

                    NumberAnimation {
                        target: nudge
                        property: "x"
                        to: 12
                        duration: 90
                    }

                    NumberAnimation {
                        target: nudge
                        property: "x"
                        to: -6
                        duration: 70
                    }

                    NumberAnimation {
                        target: nudge
                        property: "x"
                        to: 0
                        duration: 60
                    }
                }

                MaterialSymbol {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "lock"
                    font.pixelSize: 18
                    color: Appearance.mutedColor
                }

                TextInput {
                    id: passwordInput

                    anchors.fill: parent
                    anchors.leftMargin: 46
                    anchors.rightMargin: 56
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Appearance.fgColor
                    font.family: Appearance.fontFamily
                    font.pixelSize: 15
                    font.letterSpacing: root.showInput ? 0 : 3
                    echoMode: root.showInput ? TextInput.Normal : TextInput.Password
                    enabled: root.inputEnabled
                    text: root.password
                    onTextEdited: root.edited(text)
                    onAccepted: root.submitted()
                    activeFocusOnPress: true
                    focus: root.secure
                    selectByMouse: false
                    passwordCharacter: "●"
                    Component.onCompleted: {
                        if (root.secure)
                            forceActiveFocus();
                    }
                    Keys.onEscapePressed: event => {
                        root.edited("");
                        event.accepted = true;
                    }
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 46
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.password.length === 0
                    text: "Password"
                    color: Appearance.mutedColor
                    font.pixelSize: 15
                }

                // submit button, once something is typed
                Rectangle {
                    width: 40
                    height: 40
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 20
                    color: submitArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor
                    opacity: root.password.length > 0 ? 1 : 0
                    scale: root.password.length > 0 ? 1 : 0.6

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: "arrow_forward"
                        font.pixelSize: 20
                        color: Appearance.onAccentColor
                    }

                    MouseArea {
                        id: submitArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitted()
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // error, progress, or a prompt from the system; keeps its height when empty
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                Layout.preferredWidth: 420
                Layout.preferredHeight: 18
                horizontalAlignment: Text.AlignHCenter
                text: root.statusText || root.shownPrompt
                color: root.failed ? Appearance.accentColor : Appearance.mutedColor
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        // --- status in the corners ---
        RowLayout {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 28
            visible: !!Battery.device && Battery.device.isLaptopBattery
            spacing: 8

            MaterialSymbol {
                icon: Battery.iconName
                fill: Battery.percentage
                font.pixelSize: 22
                color: Appearance.fgColor
            }

            StyledText {
                text: Math.round(Battery.percentage * 100) + "%"
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 28
            spacing: 8

            MaterialSymbol {
                icon: "keyboard"
                font.pixelSize: 20
                color: Appearance.fgColor
            }

            StyledText {
                text: Keyboard.layout
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }
    }
}
