import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland

// The shell is the polkit agent: programs that need administrator rights (pkexec, Settings pages, GParted,
// the printer and network tools) ask here, in a GlassDialog. Loaded only while `polkit.enabled` is on (see
// shell.qml); with it off, another agent can be used. The quickshell-polkit layer has a blur rule in
// Hyprland, so only the dialog is blurred.
Scope {
    id: root

    readonly property var flow: agent.flow
    // the screen the user is looking at
    readonly property var targetScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    PolkitAgent {
        id: agent
    }

    LazyLoader {
        active: agent.isActive && root.flow !== null

        PanelWindow {
            id: window

            screen: root.targetScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell-polkit"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // transparent, but it keeps clicks off the windows below
            MouseArea {
                anchors.fill: parent
            }

            GlassDialog {
                id: dialog

                readonly property var f: root.flow
                readonly property bool failed: f ? f.supplementaryIsError && f.supplementaryMessage !== "" : false

                anchors.centerIn: parent
                icon: "lock"
                title: "Authentication required"
                message: root.flow?.message ?? ""
                buttons: [
                    {
                        "text": "Cancel",
                        "key": "cancel"
                    },
                    {
                        "text": "Authenticate",
                        "key": "ok",
                        "primary": true,
                        "enabled": field.canSubmit
                    }
                ]
                onButtonClicked: key => key === "ok" ? field.submit() : root.flow?.cancelAuthenticationRequest()
                onFailedChanged: {
                    if (failed) {
                        shake();
                        passwordInput.text = "";
                        passwordInput.forceActiveFocus();
                    }
                }
                Component.onCompleted: passwordInput.forceActiveFocus()

                // only when more than one account may approve (e.g. several administrators)
                Segmented {
                    Layout.alignment: Qt.AlignHCenter
                    visible: (root.flow?.identities.length ?? 0) > 1
                    model: (root.flow?.identities ?? []).map((id, n) => ({
                                "label": id.displayName || id.string || "",
                                "value": n
                            }))
                    value: (root.flow?.identities ?? []).indexOf(root.flow?.selectedIdentity)
                    onSelected: n => root.flow.selectedIdentity = root.flow.identities[n]
                }

                // password pill, same height and fill as a Quick Settings tile
                Rectangle {
                    id: field

                    readonly property bool canSubmit: (root.flow?.isResponseRequired ?? false) && passwordInput.text !== ""

                    function submit() {
                        if (canSubmit) {
                            root.flow.submit(passwordInput.text);
                            passwordInput.text = "";
                        }
                    }

                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: 27
                    color: passwordInput.activeFocus ? Appearance.surfaceHighColor : Appearance.surfaceColor
                    border.width: 1.5
                    border.color: dialog.failed ? Appearance.accentColor : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animNormal
                        }
                    }

                    MaterialSymbol {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "key"
                        font.pixelSize: 20
                        color: Appearance.mutedColor
                    }

                    TextInput {
                        id: passwordInput

                        anchors.fill: parent
                        anchors.leftMargin: 50
                        anchors.rightMargin: 56
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Appearance.fgColor
                        font.family: Appearance.fontFamily
                        font.pixelSize: 14
                        font.letterSpacing: (root.flow?.responseVisible ?? false) ? 0 : 3
                        echoMode: (root.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        enabled: root.flow?.isResponseRequired ?? false
                        activeFocusOnPress: true
                        selectByMouse: false
                        onAccepted: field.submit()
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 50
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text.length === 0
                        text: {
                            const p = (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "");
                            return p === "" || /^password$/i.test(p) ? "Password" : p;
                        }
                        color: Appearance.mutedColor
                        font.pixelSize: 14
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
                        opacity: field.canSubmit ? 1 : 0
                        scale: field.canSubmit ? 1 : 0.6

                        MaterialSymbol {
                            anchors.centerIn: parent
                            icon: "arrow_forward"
                            font.pixelSize: 20
                            color: Appearance.accentContrastColor
                        }

                        MouseArea {
                            id: submitArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: field.canSubmit
                            onClicked: field.submit()
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

                // error, progress, or a prompt from the system (only takes room when there is one)
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    visible: text !== ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Appearance.accentColor : Appearance.mutedColor
                    font.pixelSize: 12
                }
            }
        }
    }
}
