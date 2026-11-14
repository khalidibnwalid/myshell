import "../config/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Widgets

// Colour picker: saturation/brightness pad, hue slider, hex and RGB fields,
// eyedropper, swatches. Changes are previewed live through previewed(); Apply
// keeps the colour (applied()), Cancel, Escape or a click outside revert (cancelled()).
// Needs to live inside an ApplicationWindow.
Popup {
    id: root

    property string heading: "Colour"
    // the colour when the picker opened, for comparing and for cancelling
    property color original: "#ffffff"
    // the colour is held as hue, saturation and brightness (0–1), so a grey or a black
    // does not lose the hue you were on
    property real hue: 0
    property real sat: 0
    property real val: 1
    readonly property color value: Qt.hsva(hue, sat, val, 1)
    // fixed swatches (the theme's accent colours) and the colours picked before
    property var swatches: []
    property var recents: []
    property bool keep: false

    signal previewed(color c)
    signal applied(color c)
    signal cancelled()

    function clamp(v) {
        return Math.max(0, Math.min(1, v));
    }

    // "#rrggbb", "rrggbb", "#rgb"; null when it is not a colour
    function parseHex(text) {
        let t = String(text).trim().replace(/^#/, "");
        if (/^[0-9a-f]{3}$/i.test(t))
            t = t.split("").map(ch => ch + ch).join("");
        return /^[0-9a-f]{6}$/i.test(t) ? Qt.color("#" + t) : null;
    }

    function load(c) {
        const x = Qt.color(String(c));
        // greys have no hue: keep the one we had
        if (x.hsvHue >= 0)
            hue = x.hsvHue;
        sat = x.hsvSaturation;
        val = x.hsvValue;
    }

    function setFromColor(c) {
        load(c);
        previewed(value);
    }

    function setHsv(h, s, v) {
        hue = Math.min(0.9999, clamp(h));
        sat = clamp(s);
        val = clamp(v);
        previewed(value);
    }

    function setChannel(index, text) {
        const n = parseInt(text);
        if (isNaN(n))
            return;
        const c = value;
        const channels = [c.r, c.g, c.b];
        channels[index] = Math.max(0, Math.min(255, n)) / 255;
        setFromColor(Qt.rgba(channels[0], channels[1], channels[2], 1));
    }

    function openWith(c, title) {
        heading = title;
        original = c;
        load(c);
        keep = false;
        open();
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 332
    padding: 16
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onClosed: {
        if (!keep)
            cancelled();
    }
    // ready to type a hex code straight away
    onOpened: {
        hexField.focusInput();
        hexField.selectAll();
    }

    Overlay.modal: Rectangle {
        color: Qt.alpha("#000000", 0.4)
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.animFast
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: Appearance.animFast
        }
    }

    background: Rectangle {
        radius: 24
        color: Qt.tint(Appearance.bgColor, Qt.alpha(Appearance.fgColor, 0.1))
        border.width: 1
        border.color: Appearance.outlineColor
    }

    // eyedropper: sample any pixel on screen
    Process {
        id: dropper

        command: ["hyprpicker"]

        stdout: StdioCollector {
            onStreamFinished: {
                const c = root.parseHex(text);
                if (c)
                    root.setFromColor(c);
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: root.heading
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            IconButton {
                size: 30
                iconSize: 18
                icon: "close"
                onClicked: root.close()
            }
        }

        // --- saturation (left to right) and brightness (bottom to top) ---
        ClippingRectangle {
            id: pad

            Layout.fillWidth: true
            Layout.preferredHeight: 176
            radius: 16
            color: Qt.hsva(root.hue, 1, 1, 1)

            Rectangle {
                anchors.fill: parent

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "#ffffffff"
                    }

                    GradientStop {
                        position: 1
                        color: "#00ffffff"
                    }
                }
            }

            Rectangle {
                anchors.fill: parent

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#00000000"
                    }

                    GradientStop {
                        position: 1
                        color: "#ff000000"
                    }
                }
            }

            Rectangle {
                x: root.sat * pad.width - width / 2
                y: (1 - root.val) * pad.height - height / 2
                width: 20
                height: 20
                radius: 10
                color: root.value
                border.width: 3
                border.color: "#ffffff"

                // a thin dark ring so the handle shows on white too
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "#66000000"
                }
            }

            MouseArea {
                function pick() {
                    root.setHsv(root.hue, mouseX / width, 1 - mouseY / height);
                }

                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                onPressed: pick()
                onPositionChanged: {
                    if (pressed)
                        pick();
                }
            }
        }

        // --- hue ---
        Item {
            id: hueBar

            Layout.fillWidth: true
            Layout.preferredHeight: 20

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 3
                anchors.bottomMargin: 3
                radius: height / 2

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "#ff0000"
                    }

                    GradientStop {
                        position: 1 / 6
                        color: "#ffff00"
                    }

                    GradientStop {
                        position: 2 / 6
                        color: "#00ff00"
                    }

                    GradientStop {
                        position: 3 / 6
                        color: "#00ffff"
                    }

                    GradientStop {
                        position: 4 / 6
                        color: "#0000ff"
                    }

                    GradientStop {
                        position: 5 / 6
                        color: "#ff00ff"
                    }

                    GradientStop {
                        position: 1
                        color: "#ff0000"
                    }
                }
            }

            Rectangle {
                x: root.hue * (hueBar.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: Qt.hsva(root.hue, 1, 1, 1)
                border.width: 3
                border.color: "#ffffff"
            }

            MouseArea {
                function pick() {
                    root.setHsv(mouseX / width, root.sat, root.val);
                }

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: pick()
                onPositionChanged: {
                    if (pressed)
                        pick();
                }
            }
        }

        // --- old and new colour, hex, eyedropper ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Row {
                spacing: 2

                Rectangle {
                    width: 30
                    height: 36
                    topLeftRadius: 18
                    bottomLeftRadius: 18
                    color: root.original

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setFromColor(root.original)
                    }
                }

                Rectangle {
                    width: 30
                    height: 36
                    topRightRadius: 18
                    bottomRightRadius: 18
                    color: root.value
                }
            }

            FieldInput {
                id: hexField

                Layout.fillWidth: true
                icon: "tag"
                placeholder: "rrggbb"
                value: root.value.toString().replace("#", "")
                // a full six digits apply as you type; three digits and shorter wait for Enter
                onEdited: text => {
                    if (/^#?[0-9a-f]{6}$/i.test(text.trim()))
                        root.setFromColor(root.parseHex(text));
                }
                onCommitted: text => {
                    const c = root.parseHex(text);
                    if (c)
                        root.setFromColor(c);
                    // shows the real colour again, also when the text was not one
                    hexField.reset();
                }
            }

            IconButton {
                size: 36
                iconSize: 20
                icon: "colorize"
                onClicked: dropper.running = true
            }
        }

        // --- red, green, blue ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: ["R", "G", "B"]

                delegate: RowLayout {
                    id: channel

                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: channel.modelData
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    FieldInput {
                        id: channelField

                        Layout.fillWidth: true
                        placeholder: "0–255"
                        value: String(Math.round([root.value.r, root.value.g, root.value.b][channel.index] * 255))
                        onCommitted: text => {
                            root.setChannel(channel.index, text);
                            // 300 shows as 255, text that is not a number as the old value
                            channelField.reset();
                        }
                    }
                }
            }
        }

        // --- swatches ---
        StyledText {
            Layout.topMargin: 2
            visible: root.swatches.length > 0
            text: "Theme colours"
            color: Appearance.mutedColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Flow {
            Layout.fillWidth: true
            visible: root.swatches.length > 0
            spacing: 8

            Repeater {
                model: root.swatches

                delegate: Rectangle {
                    id: swatch

                    required property var modelData

                    width: 26
                    height: 26
                    radius: 13
                    color: modelData
                    border.width: 1
                    border.color: Appearance.outlineColor
                    scale: swatchArea.containsMouse ? 1.12 : 1

                    MouseArea {
                        id: swatchArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setFromColor(swatch.modelData)
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }
            }
        }

        StyledText {
            visible: root.recents.length > 0
            text: "Recent"
            color: Appearance.mutedColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Flow {
            Layout.fillWidth: true
            visible: root.recents.length > 0
            spacing: 8

            Repeater {
                model: root.recents

                delegate: Rectangle {
                    id: recent

                    required property var modelData

                    width: 26
                    height: 26
                    radius: 13
                    color: modelData
                    border.width: 1
                    border.color: Appearance.outlineColor
                    scale: recentArea.containsMouse ? 1.12 : 1

                    MouseArea {
                        id: recentArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setFromColor(recent.modelData)
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            PillButton {
                Layout.fillWidth: true
                text: "Cancel"
                onClicked: root.close()
            }

            PillButton {
                Layout.fillWidth: true
                toggled: true
                icon: "check"
                text: "Apply"
                onClicked: {
                    root.keep = true;
                    root.applied(root.value);
                    root.close();
                }
            }
        }
    }
}
