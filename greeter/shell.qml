import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: root

    // set by install.sh
    readonly property string userName: "__USER__"
    readonly property string cacheFile: "/var/cache/quickshell-greeter/last-session"

    // wayland sessions found in /usr/share/wayland-sessions: {name, exec}
    property var sessions: [{ name: "Hyprland", exec: "start-hyprland" }]
    property int sessionIndex: 0
    property bool sessionMenu: false
    readonly property var session: sessions[Math.min(sessionIndex, sessions.length - 1)]

    function cycleSession() {
        root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length;
    }

    Process {
        id: lister
        running: true
        command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do [ -f \"$f\" ] || continue; grep -qiE '^(Hidden|NoDisplay)=true' \"$f\" && continue; n=$(sed -n 's/^Name=//p' \"$f\" | head -1); e=$(sed -n 's/^Exec=//p' \"$f\" | head -1); [ -n \"$e\" ] && printf '%s\\t%s\\n' \"${n:-$(basename \"$f\" .desktop)}\" \"$e\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const parts = line.split("\t");
                    if (parts.length === 2 && parts[1].trim() !== "")
                        list.push({ name: parts[0], exec: parts[1].trim() });
                }
                if (list.length > 0)
                    root.sessions = list;
                lastReader.running = true;
            }
        }
    }

    // the session used last time is preselected
    Process {
        id: lastReader
        command: ["cat", root.cacheFile]
        stdout: StdioCollector {
            onStreamFinished: {
                const i = root.sessions.findIndex(x => x.name === text.trim());
                if (i >= 0)
                    root.sessionIndex = i;
            }
        }
    }

    Process {
        id: lastWriter
        command: ["sh", "-c", "printf %s \"$1\" > \"$2\"", "sh", root.session.name, root.cacheFile]
    }

    Process {
        id: power
        property var args: []
        command: ["systemctl"].concat(args)
    }

    function powerAction(what) {
        power.args = [what];
        power.running = true;
    }

    Component.onCompleted: {
        if (!Greetd.available)
            root.statusText = "greetd is not running";
    }

    property string password: ""
    property string statusText: ""
    property string prompt: ""
    property bool busy: false
    property bool ready: false
    readonly property bool failed: statusText !== "" && statusText !== "Checking…"

    Timer {
        interval: 50
        running: true
        onTriggered: root.ready = true
    }

    function submit() {
        if (root.busy || root.password === "" || !Greetd.available)
            return;
        root.sessionMenu = false;
        root.busy = true;
        root.statusText = "Checking…";
        if (Greetd.state === GreetdState.Inactive)
            Greetd.createSession(root.userName);
        else {
            Greetd.respond(root.password);
            root.password = "";
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.password);
                root.password = "";
            } else {
                root.statusText = error ? message : "";
                Greetd.respond("");
            }
        }

        function onAuthFailure(message) {
            root.busy = false;
            root.password = "";
            root.statusText = "Wrong password";
            Greetd.cancelSession();
        }

        function onReadyToLaunch() {
            root.statusText = "Welcome";
            lastWriter.running = true;
            const cmd = root.session.exec.replace(/%[a-zA-Z]/g, "").trim().split(/\s+/);
            // systemd-cat sends the session's output to the journal instead of the console
            Greetd.launch(["systemd-cat", "-t", "session"].concat(cmd), ["XDG_SESSION_TYPE=wayland"], true);
        }

        function onError(error) {
            root.busy = false;
            root.statusText = error;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: Theme.bgColor

            Item {
                anchors.fill: parent

                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: "wallpaper"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: wallpaper
                    visible: wallpaper.status === Image.Ready
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                    scale: 1.06
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha(Theme.bgColor, 0.35) }
                        GradientStop { position: 1; color: Qt.alpha(Theme.bgColor, 0.72) }
                    }
                }

                Item {
                    id: stage
                    anchors.fill: parent
                    opacity: root.ready ? 1 : 0
                    scale: root.ready ? 1 : 1.03

                    Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animSlow
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.easeOut
                        }
                    }

                    SystemClock {
                        id: clock
                        precision: SystemClock.Minutes
                    }

                    // --- clock ---
                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(parent.height * 0.16)
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toUpperCase()
                            color: Theme.mutedColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 3
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 14

                            Text {
                                text: Qt.formatDateTime(clock.date, "hh ap").replace(/ ?[ap]m/i, "")
                                color: Theme.fgColor
                                font.family: Theme.fontFamily
                                font.pixelSize: 132
                                font.weight: Font.Bold
                                font.letterSpacing: -3
                            }

                            Text {
                                text: Qt.formatDateTime(clock.date, "mm")
                                color: Theme.accentColor
                                font.family: Theme.fontFamily
                                font.pixelSize: 132
                                font.weight: Font.Bold
                                font.letterSpacing: -3
                            }
                        }
                    }

                    // --- user + password ---
                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.round(parent.height * 0.14)
                        spacing: 0

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 84
                            implicitHeight: 84
                            radius: 42
                            color: Qt.alpha(Theme.fgColor, 0.12)
                            border.width: 2
                            border.color: Qt.alpha(Theme.fgColor, 0.18)

                            Text {
                                anchors.centerIn: parent
                                text: root.userName.charAt(0).toUpperCase()
                                color: Theme.accentColor
                                font.family: Theme.fontFamily
                                font.pixelSize: 34
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 14
                            text: root.userName
                            color: Theme.fgColor
                            font.family: Theme.fontFamily
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
                            color: Qt.alpha(Theme.fgColor, 0.1)
                            border.width: 1.5
                            border.color: root.failed ? Theme.accentColor : (input.activeFocus ? Qt.alpha(Theme.fgColor, 0.45) : Qt.alpha(Theme.fgColor, 0.16))

                            transform: Translate { id: nudge }

                            SequentialAnimation {
                                id: shake
                                NumberAnimation { target: nudge; property: "x"; to: -12; duration: 50 }
                                NumberAnimation { target: nudge; property: "x"; to: 12; duration: 90 }
                                NumberAnimation { target: nudge; property: "x"; to: -6; duration: 70 }
                                NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60 }
                            }

                            Connections {
                                target: root
                                function onFailedChanged() {
                                    if (root.failed)
                                        shake.restart();
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                text: "lock"
                                color: Theme.mutedColor
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 18
                                renderType: Text.NativeRendering
                            }

                            TextInput {
                                id: input
                                anchors.fill: parent
                                anchors.leftMargin: 46
                                anchors.rightMargin: 56
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                color: Theme.fgColor
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.letterSpacing: 3
                                echoMode: TextInput.Password
                                passwordCharacter: "●"
                                enabled: !root.busy
                                text: root.password
                                focus: true
                                onTextEdited: root.password = text
                                onAccepted: root.submit()
                                Component.onCompleted: forceActiveFocus()
                                onEnabledChanged: if (enabled) forceActiveFocus()
                                Keys.onEscapePressed: event => {
                                    root.password = "";
                                    root.sessionMenu = false;
                                    event.accepted = true;
                                }
                                Keys.onTabPressed: event => {
                                    root.cycleSession();
                                    event.accepted = true;
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 46
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.password.length === 0
                                text: "Password"
                                color: Theme.mutedColor
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                            }

                            Rectangle {
                                width: 40
                                height: 40
                                anchors.right: parent.right
                                anchors.rightMargin: 7
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 20
                                color: submitArea.containsMouse ? Theme.accentColorLight : Theme.accentColor
                                opacity: root.password.length > 0 ? 1 : 0
                                scale: root.password.length > 0 ? 1 : 0.6

                                Text {
                                    anchors.centerIn: parent
                                    text: "arrow_forward"
                                    color: Theme.accentContrastColor
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 20
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    id: submitArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.submit()
                                }

                                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 12
                            Layout.preferredWidth: 420
                            Layout.preferredHeight: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: root.statusText
                            color: root.failed ? Theme.accentColor : Theme.mutedColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    // --- session picker (bottom left) ---
                    Item {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 28
                        width: sessionPill.width
                        height: sessionPill.height

                        Rectangle {
                            id: sessionMenuBox
                            anchors.left: parent.left
                            anchors.bottom: sessionPill.top
                            anchors.bottomMargin: 8
                            width: Math.max(220, sessionCol.implicitWidth + 16)
                            height: sessionCol.implicitHeight + 16
                            radius: 18
                            color: Qt.alpha(Theme.bgColor, 0.85)
                            border.width: 1
                            border.color: Qt.alpha(Theme.fgColor, 0.16)
                            visible: opacity > 0
                            opacity: root.sessionMenu ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                            Column {
                                id: sessionCol
                                anchors.centerIn: parent
                                spacing: 2

                                Repeater {
                                    model: root.sessions

                                    Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: sessionMenuBox.width - 16
                                        height: 38
                                        radius: 12
                                        color: rowArea.containsMouse ? Qt.alpha(Theme.fgColor, 0.12) : "transparent"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name
                                            color: index === root.sessionIndex ? Theme.accentColor : Theme.fgColor
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: index === root.sessionIndex ? Font.DemiBold : Font.Normal
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: index === root.sessionIndex
                                            text: "check"
                                            color: Theme.accentColor
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 18
                                            renderType: Text.NativeRendering
                                        }

                                        MouseArea {
                                            id: rowArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.sessionIndex = index;
                                                root.sessionMenu = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: sessionPill
                            width: pillRow.implicitWidth + 28
                            height: 40
                            radius: 20
                            color: pillArea.containsMouse ? Qt.alpha(Theme.fgColor, 0.16) : Qt.alpha(Theme.fgColor, 0.1)
                            border.width: 1
                            border.color: Qt.alpha(Theme.fgColor, 0.16)

                            Row {
                                id: pillRow
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "desktop_windows"
                                    color: Theme.mutedColor
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 18
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.session.name
                                    color: Theme.fgColor
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.sessions.length > 1
                                    text: root.sessionMenu ? "expand_more" : "expand_less"
                                    color: Theme.mutedColor
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 18
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                id: pillArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sessionMenu = root.sessions.length > 1 && !root.sessionMenu
                            }
                        }
                    }

                    // --- power (bottom right) ---
                    Row {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 28
                        spacing: 8

                        Repeater {
                            model: [
                                { icon: "restart_alt", action: "reboot" },
                                { icon: "power_settings_new", action: "poweroff" }
                            ]

                            Rectangle {
                                required property var modelData
                                width: 40
                                height: 40
                                radius: 20
                                color: pArea.containsMouse ? Qt.alpha(Theme.fgColor, 0.16) : Qt.alpha(Theme.fgColor, 0.1)
                                border.width: 1
                                border.color: Qt.alpha(Theme.fgColor, 0.16)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    color: Theme.fgColor
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 20
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    id: pArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.powerAction(modelData.action)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
