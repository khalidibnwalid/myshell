import "../config/"
import "../services/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// The connected Wi-Fi as a QR code a phone camera can join with, and its password (hidden until
// asked, with copy). Used by Quick Settings and Settings → Network. The code is drawn by qrencode
// into the private runtime folder and removed when this goes away.
ColumnLayout {
    id: root

    // each one its own file, so two open at once do not share a picture
    readonly property string qrFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-wifi-share-" + Math.floor(Math.random() * 1e9) + ".png"
    property string ssid: ""
    property string password: ""
    // "loading", "ready", or why it cannot be shared: "enterprise", "nosecret", "failed", "noqrencode"
    property string status: "loading"
    property bool revealed: false
    // changes the picture's address so a new code is read, not the cached one
    property int generation: 0

    spacing: 14
    Component.onCompleted: makeProc.running = true
    Component.onDestruction: Quickshell.execDetached(["rm", "-f", qrFile])

    Process {
        id: makeProc

        // $1 = the PNG to write. Prints the status, the name and the password on three lines.
        // The name and password are escaped the way the WIFI: format asks (\ ; , : ").
        command: ["sh", "-c", "command -v qrencode >/dev/null || { echo noqrencode; exit; }; "
            + "c=$(nmcli -t -f NAME,TYPE connection show --active | sed -n 's/^\\(.*\\):802-11-wireless$/\\1/p' | head -n1 | sed 's/\\\\:/:/g'); "
            + "[ -n \"$c\" ] || { echo failed; exit; }; "
            + "ssid=$(nmcli -s -g 802-11-wireless.ssid connection show \"$c\"); "
            + "km=$(nmcli -s -g 802-11-wireless-security.key-mgmt connection show \"$c\" 2>/dev/null); "
            + "psk=$(nmcli -s -g 802-11-wireless-security.psk connection show \"$c\" 2>/dev/null); "
            + "esc() { printf %s \"$1\" | sed 's/[\\\\;,:\"]/\\\\&/g'; }; "
            + "case \"$km\" in wpa-eap|wpa-eap-suite-b-192) echo enterprise; printf '%s\\n' \"$ssid\"; exit;; '') t=nopass;; none) t=WEP;; *) t=WPA;; esac; "
            + "if [ \"$t\" != nopass ] && [ -z \"$psk\" ]; then echo nosecret; printf '%s\\n' \"$ssid\"; exit; fi; "
            + "if [ \"$t\" = nopass ]; then q=\"WIFI:T:nopass;S:$(esc \"$ssid\");;\"; else q=\"WIFI:T:$t;S:$(esc \"$ssid\");P:$(esc \"$psk\");;\"; fi; "
            + "printf %s \"$q\" | qrencode -t PNG -s 12 -m 2 -o \"$1\" || { echo failed; exit; }; "
            + "echo ready; printf '%s\\n%s\\n' \"$ssid\" \"$psk\"", "sh", root.qrFile]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.status = (lines[0] || "failed").trim();
                root.ssid = lines[1] ?? "";
                root.password = lines[2] ?? "";
                root.generation++;
            }
        }
    }

    // the code, dark on white so any camera reads it
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        visible: root.status === "ready"
        implicitWidth: 236
        implicitHeight: 236
        radius: 24
        color: "white"

        Image {
            anchors.fill: parent
            anchors.margins: 14
            source: root.status === "ready" ? "file://" + root.qrFile + "?" + root.generation : ""
            fillMode: Image.PreserveAspectFit
            smooth: false
            cache: false
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.status === "ready"
        horizontalAlignment: Text.AlignHCenter
        text: "Point a phone's camera at the code to join"
        color: Appearance.mutedColor
        font.pixelSize: 12
    }

    // why there is no code
    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        visible: root.status !== "ready"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: Appearance.mutedColor
        font.pixelSize: 13
        text: ({
                "loading": "Making the code…",
                "enterprise": "This network signs in with an account (WPA Enterprise); a QR code cannot carry that.",
                "nosecret": "The password of this network is kept by your keyring, not by NetworkManager, so it cannot be read here.",
                "noqrencode": "Install qrencode to make the code.",
                "failed": "Not connected to a Wi-Fi network."
            })[root.status] ?? "Could not make the code."
    }

    // the password, hidden until asked, with copy
    Rectangle {
        Layout.fillWidth: true
        visible: root.status === "ready" && root.password !== ""
        implicitHeight: 52
        radius: 22
        color: Appearance.surfaceColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 8
            spacing: 6

            MaterialSymbol {
                icon: "key"
                font.pixelSize: 18
                color: Appearance.mutedColor
            }

            StyledText {
                Layout.fillWidth: true
                text: root.revealed ? root.password : "•".repeat(Math.min(16, root.password.length))
                elide: Text.ElideRight
                font.pixelSize: 13
            }

            IconButton {
                icon: root.revealed ? "visibility_off" : "visibility"
                Accessible.name: root.revealed ? "Hide the password" : "Show the password"
                ToolTip.visible: hovered
                ToolTip.text: root.revealed ? "Hide" : "Show"
                onClicked: root.revealed = !root.revealed
            }

            IconButton {
                icon: "content_copy"
                Accessible.name: "Copy the password"
                ToolTip.visible: hovered
                ToolTip.text: "Copy"
                onClicked: Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy && notify-send -a Wi-Fi 'Password copied' \"$2\"", "sh", root.password, root.ssid])
            }
        }
    }
}
