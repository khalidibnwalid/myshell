import "../../components/"
import "../../config/"
import QtQuick

// Text with a soft drop shadow behind it, for the widgets that sit straight on the wallpaper.
// `look` is the widget's own look (see WidgetFrame): font, weight and shadow can be changed per widget.
Item {
    id: root

    property var look: ({})
    property string text
    // the digits as typed (0-9), shown as Arabic-Indic ones when the widget's look asks for it
    readonly property string shown: look.arabic ? text.replace(/[0-9]/g, d => String.fromCharCode(0x0660 + parseInt(d))) : text
    property alias color: main.color
    property alias pixelSize: main.font.pixelSize
    property int weight: Font.Black
    property alias letterSpacing: main.font.letterSpacing
    property alias wordSpacing: main.font.wordSpacing
    property real shadow: 4
    // how strong the shadow is: 0 none, 1 soft, 2 strong
    readonly property real level: look.shadow ?? 1

    implicitWidth: main.implicitWidth
    implicitHeight: main.implicitHeight

    StyledText {
        visible: root.level > 0
        x: root.shadow * root.level
        y: root.shadow * 1.25 * root.level
        text: root.shown
        color: root.level > 1 ? "#99000000" : "#59000000"
        font: main.font
    }

    StyledText {
        id: main

        text: root.shown
        font.family: root.look.family ?? Appearance.fontFamily
        font.weight: root.look.weight ?? root.weight
    }
}
