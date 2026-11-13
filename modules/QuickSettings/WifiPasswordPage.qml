import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var accessPoint
    property var stackView
    property string errorText: ""
    readonly property bool connecting: Network.connecting && Network.connectingSsid === accessPoint.ssid

    implicitHeight: layout.implicitHeight + 32
    Component.onCompleted: passwordField.forceActiveFocus()

    function connect() {
        if (connecting || passwordField.text.length === 0)
            return;
        errorText = "";
        Network.connectToNetwork(accessPoint.ssid, passwordField.text);
    }

    Connections {
        target: Network
        function onConnectionFinished(success, ssid) {
            if (ssid !== root.accessPoint.ssid)
                return;
            if (success) {
                passwordField.clear();
                root.stackView.pop();
            } else {
                root.errorText = Network.connectionError;
                passwordField.forceActiveFocus();
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 14

        PageHeader {
            Layout.fillWidth: true
            title: "Join network"
            subtitle: root.accessPoint.ssid
            onBack: stackView.pop()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 14

            MaterialSymbol {
                icon: Network.getStatusIcon(root.accessPoint.strength)
                color: Appearance.accentColor
                font.pixelSize: 26
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.accessPoint.ssid
                    elide: Text.ElideRight
                    font.weight: Font.Medium
                }

                StyledText {
                    text: "Secured network"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                }
            }

            MaterialSymbol {
                icon: "lock"
                color: Appearance.mutedColor
                font.pixelSize: 18
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 26
            color: Appearance.surfaceColor
            border.width: passwordField.activeFocus ? 1 : 0
            border.color: Appearance.accentColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 8
                spacing: 8

                TextField {
                    id: passwordField

                    Layout.fillWidth: true
                    placeholderText: "Password"
                    placeholderTextColor: Appearance.mutedColor
                    color: Appearance.fgColor
                    selectionColor: Appearance.accentColor
                    selectedTextColor: Appearance.onAccentColor
                    font.family: Appearance.fontFamily
                    font.pixelSize: 15
                    echoMode: revealPassword.checked ? TextInput.Normal : TextInput.Password
                    selectByMouse: true
                    background: null
                    enabled: !root.connecting
                    onAccepted: root.connect()
                }

                IconButton {
                    id: revealPassword

                    property bool checked: false

                    icon: checked ? "visibility_off" : "visibility"
                    onClicked: checked = !checked
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.errorText !== ""
            text: root.errorText
            color: Appearance.accentColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PillButton {
                Layout.fillWidth: true
                text: "Cancel"
                icon: "close"
                onClicked: stackView.pop()
            }

            PillButton {
                Layout.fillWidth: true
                text: root.connecting ? "Connecting…" : "Connect"
                icon: root.connecting ? "sync" : "wifi"
                toggled: true
                enabled: passwordField.text.length > 0 && !root.connecting
                onClicked: root.connect()
            }
        }
    }
}
