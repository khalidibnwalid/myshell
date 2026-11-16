import "../../components"
import "../../config"
import "../../services" as Services
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Chat with Claude or Codex in a full-height panel beside the bar, toggled from the bar.
// bind = $mainMod, A, global, quickshell:agent
Scope {
    id: root

    readonly property bool open: Services.WindowManager.agentVisible
    readonly property var agent: Services.Agent
    readonly property string name: agent.names[agent.backend]
    property bool showHistory: false
    property bool showModels: false
    readonly property var ideas: [
        {
            "icon": "terminal",
            "text": "Explain a shell command"
        },
        {
            "icon": "commit",
            "text": "Write a commit message"
        },
        {
            "icon": "bug_report",
            "text": "Help me fix an error"
        }
    ]
    // commands of the panel itself; any other /command is passed to the tool
    readonly property var localCommands: [
        {
            "name": "/new",
            "icon": "edit_square",
            "about": "Start a new chat"
        },
        {
            "name": "/history",
            "icon": "forum",
            "about": "See your conversations"
        },
        {
            "name": "/claude",
            "icon": "auto_awesome",
            "about": "New chat with Claude"
        },
        {
            "name": "/codex",
            "icon": "terminal",
            "about": "New chat with Codex"
        },
        {
            "name": "/model",
            "icon": "tune",
            "about": "Choose the model"
        },
        {
            "name": "/stop",
            "icon": "stop_circle",
            "about": "Stop the answer"
        },
        {
            "name": "/delete",
            "icon": "delete",
            "about": "Delete this conversation"
        }
    ]

    function ago(ms) {
        const m = Math.floor((Date.now() - ms) / 60000);
        if (m < 1)
            return "now";
        if (m < 60)
            return m + " min ago";
        if (m < 1440)
            return Math.floor(m / 60) + " h ago";
        return Math.floor(m / 1440) + " d ago";
    }

    function baseName(path) {
        return path.substring(path.lastIndexOf("/") + 1);
    }

    // true when the text was a command of the panel and has been run
    function runLocal(text) {
        switch (text.trim()) {
        case "/new":
        case "/clear":
            agent.newChat();
            break;
        case "/history":
            showHistory = true;
            break;
        case "/claude":
        case "/codex":
            if (agent.available.indexOf(text.trim().substring(1)) >= 0) {
                agent.pick(text.trim().substring(1));
                if (agent.current)
                    agent.newChat();
            }
            break;
        case "/model":
            showModels = true;
            break;
        case "/stop":
            agent.stop();
            break;
        case "/delete":
            if (agent.current)
                agent.remove(agent.currentId);
            break;
        default:
            return false;
        }
        return true;
    }

    GlobalShortcut {
        name: "agent"
        onPressed: Services.WindowManager.agentVisible = !Services.WindowManager.agentVisible
    }

    // qs ipc call agent toggle | open | close | ask "question"
    IpcHandler {
        function toggle(): void {
            Services.WindowManager.agentVisible = !Services.WindowManager.agentVisible;
        }

        function open(): void {
            Services.WindowManager.agentVisible = true;
        }

        function close(): void {
            Services.WindowManager.agentVisible = false;
        }

        function ask(text: string): void {
            Services.WindowManager.agentVisible = true;
            root.showHistory = false;
            root.agent.send(text);
        }

        target: "agent"
    }

    Timer {
        id: closeTimer

        interval: Appearance.animNormal + 30
    }

    Connections {
        function onAgentVisibleChanged() {
            if (!Services.WindowManager.agentVisible)
                closeTimer.restart();
        }

        target: Services.WindowManager
    }

    // a click anywhere else closes it; the bar stays usable so its button can toggle
    HyprlandFocusGrab {
        windows: [window, ...Services.WindowManager.barWindows, ...Services.WindowManager.barPopups]
        active: root.open && !picker.visible
        onCleared: {
            if (!picker.visible)
                Services.WindowManager.agentVisible = false;
        }
    }

    FileDialog {
        id: picker

        title: "Attach files"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp *.gif)", "All files (*)"]
        onAccepted: {
            for (const f of selectedFiles)
                root.agent.attach(f.toString());
        }
    }

    PanelWindow {
        id: window

        readonly property bool barRight: Config.panelRight
        readonly property bool shown: root.open && backingWindowVisible
        // the commands offered while the message starts with "/"
        readonly property var matches: {
            const t = input.text;
            if (!t.startsWith("/") || /\s/.test(t))
                return [];
            const own = root.localCommands.filter(c => (c.name !== "/claude" && c.name !== "/codex") || root.agent.available.indexOf(c.name.substring(1)) >= 0);
            const tool = (root.agent.toolCommands[root.agent.backend] || []).map(n => ({
                        "name": "/" + n,
                        "icon": "bolt",
                        "about": root.name + " command",
                        "tool": true
                    }));
            return own.concat(tool).filter(c => c.name.startsWith(t)).slice(0, 7);
        }
        property int matchIndex: 0
        // folders and files that complete the path being typed (@name, ~/name or /a/b)
        property var paths: []
        readonly property var menu: matches.length > 0 ? matches : paths
        readonly property string home: Quickshell.env("HOME")

        // the word the cursor is in, when it is a path
        function pathToken() {
            const before = input.text.substring(0, input.cursorPosition);
            const word = before.substring(Math.max(before.lastIndexOf(" "), before.lastIndexOf("\n")) + 1);
            if (word.startsWith("@") || word.startsWith("~/") || (word.startsWith("/") && word.indexOf("/", 1) > 0))
                return word;
            return "";
        }

        function lookUp() {
            const word = pathToken();
            if (word === "") {
                paths = [];
                return;
            }
            const full = word.startsWith("@") ? home + "/" + word.substring(1) : (word.startsWith("~/") ? home + word.substring(1) : word);
            pathProc.word = word;
            pathProc.command = ["sh", "-c", "ls -1dp --group-directories-first -- \"$1\"* 2>/dev/null | head -7", "sh", full];
            pathProc.running = true;
        }

        function shown(word, full) {
            if (word.startsWith("@"))
                return "@" + full.substring(home.length + 1);
            if (word.startsWith("~/"))
                return "~" + full.substring(home.length);
            return full;
        }

        Process {
            id: pathProc

            property string word: ""

            stdout: StdioCollector {
                onStreamFinished: {
                    if (pathProc.word !== window.pathToken())
                        return;
                    window.paths = text.split("\n").filter(l => l !== "").map(l => ({
                                "name": root.baseName(l.replace(/\/$/, "")) + (l.endsWith("/") ? "/" : ""),
                                "icon": l.endsWith("/") ? "folder" : "description",
                                "about": l.endsWith("/") ? "Folder" : "File",
                                "path": window.shown(pathProc.word, l)
                            }));
                }
            }
        }

        Timer {
            id: pathTimer

            interval: 120
            onTriggered: window.lookUp()
        }

        function choose(command) {
            if (command.path) {
                const word = pathToken();
                const start = input.cursorPosition - word.length;
                const rest = input.text.substring(input.cursorPosition);
                input.text = input.text.substring(0, start) + command.path + (command.path.endsWith("/") ? "" : " ") + rest;
                input.cursorPosition = start + command.path.length + (command.path.endsWith("/") ? 0 : 1);
                return;
            }
            if (command.tool) {
                input.text = command.name + " ";
                input.cursorPosition = input.text.length;
                return;
            }
            input.text = "";
            root.runLocal(command.name);
        }

        function submit() {
            if (menu.length > 0) {
                choose(menu[Math.min(matchIndex, menu.length - 1)]);
                return;
            }
            if (root.runLocal(input.text)) {
                input.text = "";
                return;
            }
            if (root.agent.busy)
                return;
            if (input.text.trim() === "" && root.agent.attachments.length === 0)
                return;
            root.showHistory = false;
            root.agent.send(input.text);
            input.text = "";
        }

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open || closeTimer.running
        color: "transparent"
        implicitWidth: 440
        // it lies over the windows; it does not push them aside
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        onVisibleChanged: {
            if (visible) {
                input.forceActiveFocus();
                list.positionViewAtEnd();
            }
        }

        anchors {
            top: true
            bottom: true
            right: barRight
            left: !barRight
        }

        margins {
            top: 10
            bottom: 10
            right: 10
            left: 10
        }

        Rectangle {
            id: card

            anchors.fill: parent
            radius: 28
            color: Appearance.panelColor
            border.width: 1
            border.color: Appearance.hairlineColor
            opacity: window.shown ? 1 : 0

            transform: Translate {
                x: window.shown ? 0 : (window.barRight ? 46 : -46)

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.animNormal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.easeOut
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animFast
                }
            }

            // files dropped on the panel are attached
            DropArea {
                anchors.fill: parent
                onDropped: drop => {
                    for (const u of drop.urls)
                        root.agent.attach(u.toString());
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // ---- header ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46

                        AgentFace {
                            id: avatar

                            anchors.fill: parent
                            size: 46

                            // it sways while the agent is working
                            SequentialAnimation on rotation {
                                running: root.agent.busy
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) avatar.rotation = 0

                                NumberAnimation {
                                    to: 10
                                    duration: 450
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: -10
                                    duration: 900
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 0
                                    duration: 450
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 13
                            height: 13
                            radius: 6.5
                            color: root.agent.available.length > 0 ? "#7bd88f" : Appearance.mutedColor
                            border.width: 2
                            border.color: Appearance.bgColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.showHistory ? "Conversations" : (root.agent.available.length > 0 ? root.name : "Agent")
                            elide: Text.ElideRight
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: {
                                if (root.showHistory)
                                    return root.agent.conversations.length + " saved";
                                if (root.agent.available.length === 0)
                                    return "Not installed";
                                if (root.agent.answeringHere)
                                    return root.agent.activity !== "" ? root.agent.activity + "…" : (root.agent.streamText !== "" ? "Writing…" : "Thinking…");
                                return root.agent.current ? root.agent.current.title : "Here to help";
                            }
                            color: Appearance.mutedColor
                            font.pixelSize: 12
                        }
                    }

                    IconButton {
                        icon: "forum"
                        size: 36
                        toggled: root.showHistory
                        onClicked: root.showHistory = !root.showHistory

                        ToolTip.visible: hovered
                        ToolTip.text: "Conversations"
                    }

                    IconButton {
                        icon: "edit_square"
                        size: 36
                        onClicked: {
                            root.showHistory = false;
                            root.agent.newChat();
                            input.forceActiveFocus();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: "New chat"
                    }

                    IconButton {
                        icon: "close"
                        size: 36
                        onClicked: Services.WindowManager.agentVisible = false
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Appearance.hairlineColor
                }

                // ================= conversations =================
                ListView {
                    id: history

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.showHistory
                    clip: true
                    spacing: 3
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.agent.conversations

                    delegate: ListRow {
                        id: row

                        required property var modelData
                        required property int index

                        width: history.width
                        implicitHeight: 60
                        first: index === 0
                        last: index === root.agent.conversations.length - 1
                        active: modelData.id === root.agent.currentId
                        image: root.agent.icons[modelData.backend] || ""
                        icon: root.agent.symbols[modelData.backend]
                        iconBox: 28
                        title: modelData.title
                        subtitle: root.agent.names[modelData.backend] + "  ·  " + modelData.messages.length + " messages  ·  " + root.ago(modelData.updated)
                        trailingSpace: 30
                        onClicked: {
                            root.agent.open(modelData.id);
                            root.showHistory = false;
                        }

                        IconButton {
                            id: removeButton

                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.hovered || removeButton.hovered
                            icon: "close"
                            size: 30
                            iconSize: 18
                            color: row.contentColor
                            onClicked: root.agent.remove(row.modelData.id)
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: root.agent.conversations.length === 0
                        spacing: 8

                        MaterialSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: "forum"
                            font.pixelSize: 40
                            color: Appearance.mutedColor
                            opacity: 0.6
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No conversations yet"
                            color: Appearance.mutedColor
                        }
                    }
                }

                // ================= the chat =================
                ListView {
                    id: list

                    readonly property bool atEnd: contentHeight <= height || contentY >= contentHeight - height - 60

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.showHistory
                    clip: true
                    spacing: 12
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.agent.messages
                    onCountChanged: Qt.callLater(positionViewAtEnd)

                    Connections {
                        function onStreamTextChanged() {
                            if (list.atEnd)
                                Qt.callLater(list.positionViewAtEnd);
                        }

                        target: root.agent
                    }

                    delegate: Item {
                        id: entry

                        required property var modelData
                        readonly property bool mine: modelData.role === "user"
                        readonly property bool failed: modelData.role === "error"
                        readonly property var files: modelData.files || []

                        width: list.width
                        height: bubble.height

                        Text {
                            id: measure

                            visible: false
                            text: entry.modelData.text
                            textFormat: Text.PlainText
                            font.family: Appearance.fontFamily
                            font.pixelSize: 14
                        }

                        HoverHandler {
                            id: entryHover
                        }

                        AgentFace {
                            visible: !entry.mine
                            failed: entry.failed
                        }

                        Rectangle {
                            id: bubble

                            x: entry.mine ? parent.width - width : 36
                            width: entry.mine ? Math.min(list.width * 0.82, Math.max(measure.implicitWidth + 32, entry.files.length > 0 ? 200 : 0)) : list.width - 36
                            height: content.implicitHeight + 24
                            radius: 20
                            // the corner next to the speaker is the pointed one
                            topRightRadius: entry.mine ? 6 : 20
                            topLeftRadius: entry.mine ? 20 : 6
                            color: entry.mine ? Appearance.accentColor : (entry.failed ? Qt.alpha("#ff5f5f", 0.16) : Appearance.surfaceColor)

                            Column {
                                id: content

                                x: 16
                                y: 12
                                width: bubble.width - 32
                                spacing: 8

                                Flow {
                                    width: parent.width
                                    visible: entry.files.length > 0
                                    spacing: 6

                                    Repeater {
                                        model: entry.files

                                        ClippingRectangle {
                                            id: sent

                                            required property string modelData
                                            readonly property bool picture: root.agent.isImage(modelData)

                                            width: picture ? 84 : fileName.implicitWidth + 44
                                            height: picture ? 84 : 32
                                            radius: 12
                                            color: Qt.alpha(Appearance.accentContrastColor, 0.14)

                                            Image {
                                                anchors.fill: parent
                                                visible: sent.picture
                                                source: sent.picture ? "file://" + sent.modelData : ""
                                                sourceSize: Qt.size(168, 168)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                            }

                                            MaterialSymbol {
                                                x: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: !sent.picture
                                                icon: "description"
                                                font.pixelSize: 18
                                                color: Appearance.accentContrastColor
                                            }

                                            StyledText {
                                                id: fileName

                                                x: 34
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: !sent.picture
                                                text: root.baseName(sent.modelData)
                                                color: Appearance.accentContrastColor
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                }

                                TextEdit {
                                    id: body

                                    width: parent.width
                                    text: entry.mine || entry.failed ? entry.modelData.text : root.agent.toHtml(entry.modelData.text, Appearance.accentColor.toString())
                                    textFormat: entry.mine || entry.failed ? TextEdit.PlainText : TextEdit.RichText
                                    wrapMode: TextEdit.Wrap
                                    readOnly: true
                                    selectByMouse: true
                                    color: entry.mine ? Appearance.accentContrastColor : Appearance.fgColor
                                    selectionColor: entry.mine ? Appearance.accentContrastColor : Appearance.accentColor
                                    selectedTextColor: entry.mine ? Appearance.accentColor : Appearance.accentContrastColor
                                    font.family: Appearance.fontFamily
                                    font.pixelSize: 14
                                    onLinkActivated: link => Qt.openUrlExternally(link)
                                }
                            }

                            IconButton {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 4
                                visible: !entry.mine && !entry.failed
                                opacity: entryHover.hovered ? 1 : 0
                                icon: "content_copy"
                                size: 28
                                iconSize: 15
                                onClicked: Quickshell.execDetached(["wl-copy", "--", entry.modelData.text])

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Appearance.animFast
                                    }
                                }
                            }
                        }
                    }

                    // the reply being written, or three dots while it thinks
                    footer: Item {
                        width: list.width
                        height: root.agent.answeringHere ? typing.height + 12 : 0
                        visible: root.agent.answeringHere

                        AgentFace {
                            y: 12
                        }

                        Rectangle {
                            id: typing

                            x: 36
                            y: 12
                            width: root.agent.streamText === "" ? 74 : list.width - 36
                            height: root.agent.streamText === "" ? 42 : live.implicitHeight + 24
                            radius: 20
                            topLeftRadius: 6
                            color: Appearance.surfaceColor

                            Row {
                                anchors.centerIn: parent
                                visible: root.agent.streamText === ""
                                spacing: 6

                                Repeater {
                                    model: 3

                                    Rectangle {
                                        id: dot

                                        required property int index

                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: Appearance.accentColor

                                        SequentialAnimation on y {
                                            running: root.agent.answeringHere && root.agent.streamText === ""
                                            loops: Animation.Infinite

                                            PauseAnimation {
                                                duration: dot.index * 140
                                            }

                                            NumberAnimation {
                                                to: -5
                                                duration: 220
                                                easing.type: Easing.OutQuad
                                            }

                                            NumberAnimation {
                                                to: 0
                                                duration: 220
                                                easing.type: Easing.InQuad
                                            }

                                            PauseAnimation {
                                                duration: (2 - dot.index) * 140 + 260
                                            }
                                        }
                                    }
                                }
                            }

                            TextEdit {
                                id: live

                                x: 16
                                y: 12
                                width: typing.width - 32
                                visible: root.agent.streamText !== ""
                                text: root.agent.toHtml(root.agent.streamText, Appearance.accentColor.toString())
                                textFormat: TextEdit.RichText
                                wrapMode: TextEdit.Wrap
                                readOnly: true
                                color: Appearance.fgColor
                                font.family: Appearance.fontFamily
                                font.pixelSize: 14
                            }
                        }
                    }

                    // ---- a fresh chat ----
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 40
                        visible: root.agent.messages.length === 0 && !root.agent.answeringHere
                        spacing: 10

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 84
                            Layout.preferredHeight: 84

                            AgentFace {
                                anchors.fill: parent
                                size: 84
                            }

                            SequentialAnimation on scale {
                                running: root.open && !root.showHistory && root.agent.messages.length === 0
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 1.07
                                    duration: 1300
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 1
                                    duration: 1300
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 6
                            text: root.agent.available.length > 0 ? "Hi! I'm " + root.name : "No agent found"
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: root.agent.available.length > 0 ? "Ask me anything, attach a picture or a file, type / for commands or @ for a folder. I can read your files, but I will not change them." : "Install the claude or codex command to chat here."
                            color: Appearance.mutedColor
                            font.pixelSize: 13
                        }

                        // which tool the new chat talks to
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            visible: root.agent.available.length > 1
                            implicitWidth: toolRow.implicitWidth + 6
                            implicitHeight: 40
                            radius: 20
                            color: Appearance.surfaceColor

                            Row {
                                id: toolRow

                                anchors.centerIn: parent
                                spacing: 2

                                Repeater {
                                    model: root.agent.available

                                    Rectangle {
                                        id: tool

                                        required property string modelData
                                        readonly property bool current: modelData === root.agent.backend

                                        width: toolContent.implicitWidth + 26
                                        height: 34
                                        radius: 17
                                        color: current ? Appearance.accentColor : (toolArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

                                        Row {
                                            id: toolContent

                                            anchors.centerIn: parent
                                            spacing: 7

                                            AgentFace {
                                                anchors.verticalCenter: parent.verticalCenter
                                                backend: tool.modelData
                                                size: 20
                                            }

                                            StyledText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.agent.names[tool.modelData]
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                                color: tool.current ? Appearance.accentContrastColor : Appearance.fgColor
                                            }
                                        }

                                        MouseArea {
                                            id: toolArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.agent.pick(tool.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: root.agent.available.length > 0 ? root.ideas : []

                            PillButton {
                                required property var modelData

                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 2
                                icon: modelData.icon
                                text: modelData.text
                                onClicked: {
                                    input.text = modelData.text + ": ";
                                    input.cursorPosition = input.text.length;
                                    input.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // ---- the models of this tool ----
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.showModels
                    implicitHeight: Math.min(modelColumn.implicitHeight + 12, 320)
                    radius: 20
                    color: Appearance.surfaceColor
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 6
                        contentHeight: modelColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                    Column {
                        id: modelColumn

                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: root.agent.models[root.agent.backend] || []

                            Rectangle {
                                id: option

                                required property var modelData
                                readonly property bool current: modelData.id === root.agent.model

                                width: modelColumn.width
                                height: 42
                                radius: 14
                                color: optionArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

                                MaterialSymbol {
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: option.current ? "check_circle" : "circle"
                                    fill: option.current ? 1 : 0
                                    font.pixelSize: 18
                                    color: option.current ? Appearance.accentColor : Appearance.mutedColor
                                }

                                Column {
                                    x: 40
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 52

                                    StyledText {
                                        text: option.modelData.label
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }

                                    StyledText {
                                        width: parent.width
                                        visible: text !== ""
                                        text: option.modelData.about
                                        elide: Text.ElideRight
                                        color: Appearance.mutedColor
                                        font.pixelSize: 11
                                    }
                                }

                                MouseArea {
                                    id: optionArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.agent.pickModel(option.modelData.id);
                                        root.showModels = false;
                                        input.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                    }
                }

                // the model in use; click to change it
                Rectangle {
                    visible: root.agent.available.length > 0 && !root.showHistory
                    implicitWidth: modelRow.implicitWidth + 20
                    implicitHeight: 30
                    radius: 15
                    color: modelArea.containsMouse || root.showModels ? Appearance.surfaceHighColor : Appearance.surfaceColor

                    Row {
                        id: modelRow

                        anchors.centerIn: parent
                        spacing: 6

                        AgentFace {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 16
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.agent.model === "" ? "Default model" : root.agent.modelLabel
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: root.showModels ? "expand_more" : "expand_less"
                            font.pixelSize: 16
                            color: Appearance.mutedColor
                        }
                    }

                    MouseArea {
                        id: modelArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showModels = !root.showModels
                    }
                }

                // ---- commands that match what is typed after "/" ----
                Rectangle {
                    Layout.fillWidth: true
                    visible: window.menu.length > 0
                    implicitHeight: commandColumn.implicitHeight + 12
                    radius: 20
                    color: Appearance.surfaceColor

                    Column {
                        id: commandColumn

                        x: 6
                        y: 6
                        width: parent.width - 12
                        spacing: 2

                        Repeater {
                            model: window.menu

                            Rectangle {
                                id: command

                                required property var modelData
                                required property int index
                                readonly property bool chosen: index === Math.min(window.matchIndex, window.menu.length - 1)

                                width: commandColumn.width
                                height: 38
                                radius: 14
                                color: chosen || commandArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

                                MaterialSymbol {
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: command.modelData.icon
                                    font.pixelSize: 18
                                    color: Appearance.accentColor
                                }

                                StyledText {
                                    x: 40
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: command.modelData.name
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                StyledText {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: command.modelData.about
                                    color: Appearance.mutedColor
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: commandArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.choose(command.modelData);
                                        input.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- files waiting to be sent ----
                Flow {
                    Layout.fillWidth: true
                    visible: root.agent.attachments.length > 0
                    spacing: 6

                    Repeater {
                        model: root.agent.attachments

                        Rectangle {
                            id: chip

                            required property string modelData
                            readonly property bool picture: root.agent.isImage(modelData)

                            width: chipRow.implicitWidth + 14
                            height: 40
                            radius: 14
                            color: Appearance.surfaceColor

                            Row {
                                id: chipRow

                                x: 5
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                ClippingRectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 30
                                    radius: 9
                                    color: Appearance.surfaceHighColor

                                    Image {
                                        anchors.fill: parent
                                        visible: chip.picture
                                        source: chip.picture ? "file://" + chip.modelData : ""
                                        sourceSize: Qt.size(60, 60)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        visible: !chip.picture
                                        icon: "description"
                                        font.pixelSize: 18
                                        color: Appearance.mutedColor
                                    }
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 150)
                                    elide: Text.ElideMiddle
                                    text: root.baseName(chip.modelData)
                                    font.pixelSize: 12
                                }

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: "close"
                                    size: 24
                                    iconSize: 14
                                    onClicked: root.agent.detach(chip.modelData)
                                }
                            }
                        }
                    }
                }

                // ---- write a message ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(150, Math.max(52, input.implicitHeight + 16))
                    radius: 26
                    color: input.activeFocus ? Appearance.surfaceHighColor : Appearance.surfaceColor

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 2

                        IconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "attach_file"
                            size: 40
                            iconSize: 21
                            enabled: root.agent.available.length > 0
                            onClicked: picker.open()

                            ToolTip.visible: hovered
                            ToolTip.text: "Attach files (or paste a picture with Ctrl+V)"
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TextArea {
                                id: input

                                // keeps word autocomplete out of the message box
                                inputMethodHints: Qt.ImhSensitiveData
                                enabled: root.agent.available.length > 0
                                placeholderText: "Message " + root.name + ", or / for commands"
                                placeholderTextColor: Appearance.mutedColor
                                color: Appearance.fgColor
                                wrapMode: TextArea.Wrap
                                font.family: Appearance.fontFamily
                                font.pixelSize: 14
                                selectionColor: Appearance.accentColor
                                selectedTextColor: Appearance.accentContrastColor
                                background: null
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 4
                                verticalAlignment: TextEdit.AlignVCenter
                                onTextChanged: {
                                    window.matchIndex = 0;
                                    pathTimer.restart();
                                }
                                Keys.onPressed: event => {
                                    const menu = window.menu.length > 0;
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                        window.submit();
                                    } else if (menu && (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)) {
                                        window.matchIndex = (window.matchIndex + 1) % window.menu.length;
                                    } else if (menu && event.key === Qt.Key_Up) {
                                        window.matchIndex = (window.matchIndex - 1 + window.menu.length) % window.menu.length;
                                    } else if (event.key === Qt.Key_Escape) {
                                        if (window.matches.length > 0)
                                            input.text = "";
                                        else if (menu)
                                            window.paths = [];
                                        else
                                            Services.WindowManager.agentVisible = false;
                                    } else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
                                        // a picture on the clipboard is attached; text is pasted as usual
                                        root.agent.pasteImage();
                                        return;
                                    } else {
                                        return;
                                    }
                                    event.accepted = true;
                                }
                            }
                        }

                        Rectangle {
                            id: sendButton

                            readonly property bool ready: root.agent.busy || input.text.trim() !== "" || root.agent.attachments.length > 0

                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            color: ready ? (sendArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor) : Appearance.surfaceHighColor

                            MaterialSymbol {
                                anchors.centerIn: parent
                                icon: root.agent.busy ? "stop" : "arrow_upward"
                                fill: root.agent.busy ? 1 : 0
                                font.pixelSize: 22
                                color: sendButton.ready ? Appearance.accentContrastColor : Appearance.mutedColor
                            }

                            MouseArea {
                                id: sendArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.agent.busy ? root.agent.stop() : window.submit()
                            }
                        }
                    }
                }
            }
        }
    }
}
