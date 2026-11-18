import ".."
import QtQuick

// A picture that changes often (a tile, the selection). The next file is loaded into the hidden image and
// shown only when it is ready, so what was there stays until it can be replaced and nothing blinks.
Item {
    id: root

    property string source: ""
    property bool smooth: true
    property bool frontIsA: true

    function loaded(img) {
        if (img.status === Image.Ready)
            frontIsA = img === a;
    }

    onSourceChanged: (frontIsA ? b : a).source = source

    Image {
        id: a

        visible: root.frontIsA
        cache: false
        asynchronous: true
        smooth: root.smooth
        onStatusChanged: root.loaded(a)
    }

    Image {
        id: b

        visible: !root.frontIsA
        cache: false
        asynchronous: true
        smooth: root.smooth
        onStatusChanged: root.loaded(b)
    }
}
