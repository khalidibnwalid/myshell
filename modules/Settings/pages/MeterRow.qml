import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Layouts

// A settings row with a level bar: title and a value on top, the bar below, a note under it.
SettingCard {
    id: row

    property string icon
    property string title
    // the value on the right, e.g. "42%"
    property string detail
    property string note
    property real value: 0
    property color barColor: Appearance.accentColor

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MaterialSymbol {
            visible: row.icon !== ""
            icon: row.icon
            font.pixelSize: 20
            color: Appearance.mutedColor
        }

        StyledText {
            Layout.fillWidth: true
            text: row.title
            elide: Text.ElideRight
            font.weight: Font.Medium
        }

        StyledText {
            text: row.detail
            color: Appearance.mutedColor
        }
    }

    Meter {
        Layout.fillWidth: true
        Layout.preferredHeight: 8
        value: row.value
        fillColor: row.barColor
    }

    StyledText {
        Layout.fillWidth: true
        visible: row.note !== ""
        text: row.note
        wrapMode: Text.Wrap
        color: Appearance.mutedColor
        font.pixelSize: 12
    }
}
