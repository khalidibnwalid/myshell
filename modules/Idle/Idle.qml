import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Wayland

Scope {
    id: root

    property bool lockRequested: false
    property string password: ""
    property string statusText: ""
    property var pamContext: null

    function lockNow() {
        if (lockRequested)
            return;
        WindowManager.quickSettingsVisible = false;
        WindowManager.settingsVisible = false;
        WindowManager.searchVisible = false;
        WindowManager.clipboardVisible = false;
        password = "";
        statusText = "";
        lockRequested = true;
    }

    function startAuthentication() {
        if (!lockRequested || !sessionLock.secure)
            return;
        password = "";
        if (!pamContext)
            pamContext = pamFactory.createObject(root);
        if (!pamContext || !pamContext.start()) {
            statusText = "Couldn't start authentication. Check the system PAM login configuration.";
            if (pamContext) {
                pamContext.destroy();
                pamContext = null;
            }
            retryTimer.restart();
        }
    }

    function submitPassword() {
        if (!pamContext || !pamContext.responseRequired)
            return;
        const response = password;
        password = "";
        statusText = "Checking…";
        pamContext.respond(response);
    }

    GlobalShortcut {
        name: "lock"
        onPressed: root.lockNow()
    }

    IdleMonitor {
        timeout: Math.max(1, Config.idle.lockAfterMinutes) * 60
        enabled: Config.idle.enabled && Config.idle.lockAfterMinutes > 0 && WindowManager.idlePauseRemainingSeconds <= 0
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lockNow()
    }

    IdleMonitor {
        timeout: Math.max(1, Config.idle.screenOffAfterMinutes) * 60
        enabled: Config.idle.enabled && Config.idle.screenOffAfterMinutes > Config.idle.lockAfterMinutes
        respectInhibitors: true
        onIsIdleChanged: Hyprland.dispatch(isIdle ? "dpms off" : "dpms on")
    }

    Component {
        id: pamFactory

        PamContext {
            config: "login"
        }
    }

    Connections {
        target: root.pamContext

        function onCompleted(result) {
            if (result === PamResult.Success) {
                root.password = "";
                root.statusText = "";
                root.lockRequested = false;
                return;
            }

            root.password = "";
            root.statusText = result === PamResult.Failed ? "That password didn't match. Try again." : "Authentication is temporarily unavailable. Try again.";
            if (root.pamContext) {
                root.pamContext.destroy();
                root.pamContext = null;
            }
            retryTimer.restart();
        }

        function onPamMessage() {
            if (root.pamContext?.messageIsError)
                root.statusText = root.pamContext.message;
        }
    }

    Timer {
        id: retryTimer
        interval: 650
        onTriggered: root.startAuthentication()
    }

    WlSessionLock {
        id: sessionLock
        locked: root.lockRequested

        onSecureChanged: {
            if (secure)
                root.startAuthentication();
        }

        WlSessionLockSurface {
            color: Appearance.bgColor

            Rectangle {
                anchors.fill: parent
                color: Appearance.bgColor

                Image {
                    anchors.fill: parent
                    source: Config.appearance.wallpaper ? "file://" + Config.appearance.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#76080A0D"
                }

                Rectangle {
                    width: Math.min(700, parent.width - 48)
                    height: 282
                    anchors.centerIn: parent
                    radius: 32
                    color: Qt.alpha(Appearance.bgColor, 0.88)
                    border.width: 1.2
                    border.color: Qt.alpha(Appearance.fgColor, 0.14)

                    RowLayout {
                        id: cardContent
                        anchors.fill: parent
                        anchors.margins: 34
                        spacing: 34

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MaterialSymbol {
                                Layout.bottomMargin: 6
                                icon: "lock"
                                font.pixelSize: 23
                                color: Appearance.accentColor
                            }

                            StyledText {
                                text: Time.format("hh:mm AP")
                                font.pixelSize: 54
                                font.weight: Font.Bold
                            }

                            StyledText {
                                text: Time.format("dddd, d MMMM")
                                color: Appearance.mutedColor
                                font.pixelSize: 14
                            }

                            Item {
                                Layout.fillHeight: true
                            }

                            StyledText {
                                text: "YOUR SESSION IS PROTECTED"
                                color: Appearance.mutedColor
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: Appearance.hairlineColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            RowLayout {
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    radius: 19
                                    color: Appearance.surfaceHighColor

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        icon: "person"
                                        font.pixelSize: 20
                                        color: Appearance.accentColor
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2

                                    StyledText {
                                        text: Quickshell.env("USER") || "Session"
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                    }

                                    StyledText {
                                        text: "Welcome back"
                                        color: Appearance.mutedColor
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 54
                                radius: 27
                                color: Appearance.surfaceColor
                                border.width: passwordInput.activeFocus ? 1 : 0
                                border.color: Appearance.accentColor

                                TextInput {
                                    id: passwordInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 58
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Appearance.fgColor
                                    font.family: Appearance.fontFamily
                                    font.pixelSize: 15
                                    echoMode: root.pamContext?.responseVisible ? TextInput.Normal : TextInput.Password
                                    enabled: !!root.pamContext?.responseRequired
                                    text: root.password
                                    onTextEdited: {
                                        root.password = text;
                                        root.statusText = "";
                                    }
                                    onAccepted: root.submitPassword()
                                    activeFocusOnPress: true
                                    focus: sessionLock.secure
                                    selectByMouse: false
                                    passwordCharacter: "●"
                                    Component.onCompleted: if (sessionLock.secure) forceActiveFocus()
                                    Keys.onEscapePressed: {
                                        root.password = "";
                                        event.accepted = true;
                                    }
                                }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Password"
                                    color: Appearance.mutedColor
                                    font.pixelSize: 14
                                    visible: root.password.length === 0 && !passwordInput.activeFocus
                                }

                                Rectangle {
                                    width: 40
                                    height: 40
                                    anchors.right: parent.right
                                    anchors.rightMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 20
                                    color: submitArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        icon: "arrow_forward"
                                        font.pixelSize: 20
                                        color: Appearance.onAccentColor
                                    }

                                    MouseArea {
                                        id: submitArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.submitPassword()
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                horizontalAlignment: Text.AlignLeft
                                text: root.statusText || (root.pamContext?.message || "Enter your password to continue")
                                color: root.statusText ? Appearance.accentColor : Appearance.mutedColor
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: "ENTER TO UNLOCK  ·  ESC TO CLEAR"
                                color: Appearance.mutedColor
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
    }
}
