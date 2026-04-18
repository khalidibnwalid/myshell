import "../../config"
import "../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    property int fontSize: 20
    property string fontFamily: "Monospace"
    property string fontColor: Appearance.accentColor
    property string fontWeight: Font.Bold

    spacing: -8
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignHCenter
    Layout.bottomMargin: 12

    Text {
        Layout.alignment: Qt.AlignHCenter
        color: fontColor
        font.pixelSize: fontSize
        font.family: fontFamily
        font.weight: fontWeight
        // it doesn't allow 12-based hours without am/pm
        text: Time.format("hh ap").replace(/ ?[ap]m/i, "")
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        color: fontColor
        font.family: fontFamily
        font.pixelSize: fontSize
        font.weight: fontWeight
        text: Time.format("mm")
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        font.family: fontFamily
        color: fontColor
        font.pixelSize: fontSize
        font.weight: fontWeight
        text: Time.format("AP")
    }

}
