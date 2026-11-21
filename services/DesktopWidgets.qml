pragma Singleton
import "../config/"
import QtQuick
import Quickshell
import Quickshell.Io

// The widgets on the desktop: which there are, where, how big. They live in Config.widgetItems
// ([{ id, type, x, y, scale, style }], x and y as parts of the screen) and are changed by replacing the list.
Singleton {
    id: root

    // true while the widgets can be dragged, resized and removed (modules/Widgets)
    property bool editing: false
    // false while windows cover the desktop: the sound waves then stop listening and drawing
    property bool desktopShown: true
    onEditingChanged: {
        if (!editing)
            optionsFor = "";
    }

    readonly property var items: Config.widgetItems || []
    readonly property var types: [
        {
            "type": "clock",
            "label": "Clock",
            "icon": "schedule",
            "styles": ["stacked", "digital", "analog"]
        },
        {
            "type": "waves",
            "label": "Sound waves",
            "icon": "graphic_eq",
            "styles": ["bars", "vertical", "circular"]
        },
        {
            "type": "calendar",
            "label": "Calendar",
            "icon": "calendar_month",
            "styles": []
        }
    ]

    function typeInfo(type) {
        return types.find(t => t.type === type) ?? null;
    }

    function add(type) {
        const info = typeInfo(type);
        if (!info)
            return;
        // spread over the screen so a new widget does not hide behind another
        const n = items.length;
        const item = {
            "id": type + "-" + Date.now().toString(36),
            "type": type,
            "x": 0.04 + 0.26 * (n % 4),
            "y": 0.08 + 0.32 * (Math.floor(n / 4) % 2) + 0.03 * (n % 4),
            "scale": 1,
            "style": info.styles.length > 0 ? info.styles[0] : ""
        };
        Config.setWidgetItems(items.concat([item]));
    }

    function remove(id) {
        Config.setWidgetItems(items.filter(i => i.id !== id));
    }

    // patch: the keys to change, e.g. { x: 0.2, y: 0.3 }; null removes a key (back to its default)
    function update(id, patch) {
        Config.setWidgetItems(items.map(i => {
            if (i.id !== id)
                return i;
            const next = Object.assign({}, i, patch);
            for (const key in patch) {
                if (patch[key] === null)
                    delete next[key];
            }
            return next;
        }));
    }

    // every look option of a widget back to the default: colours, font, weight, shadow, see-through
    function resetLook(id) {
        update(id, {
            "color": null,
            "accent": null,
            "font": null,
            "weight": null,
            "shadow": null,
            "opacity": null,
            "date": null,
            "barWidth": null,
            "barCount": null,
            "barShape": null,
            "contrast": null,
            "gap": null,
            "digitGap": null,
            "numerals": null,
            "dateGap": null,
            "pulse": null
        });
    }

    // the widget whose options panel is open ("" = none)
    property string optionsFor: ""
    onOptionsForChanged: {
        if (optionsFor !== "")
            rescanFonts();
    }

    readonly property var styleLabels: ({
            "stacked": "Stacked",
            "digital": "One line",
            "analog": "Analog",
            "vertical": "Vertical",
            "circular": "Circular",
            "bars": "Bars"
        })
    readonly property var shadowLevels: ({
            "off": 0,
            "soft": 1,
            "strong": 2
        })
    // colours to pick from; the first choice in the panel is always "default" (the theme's)
    readonly property var palette: ["#ffffff", "#f3d9bf", "#ffd166", "#ff8a80", "#f48fb1", "#ce93d8", "#90caf9", "#80deea", "#a5d6a7", "#111111"]

    // Fonts to pick from: the playful ones first, then the rest of what is installed. Only names that
    // exist on this system are listed, so a playful font installed later moves to the top by itself.
    readonly property var playful: /fredoka|baloo|comfortaa|pacifico|lobster|bangers|chewy|caveat|rubik|poppins|quicksand|nunito|righteous|bungee|boogaloo|patrick|indie|permanent|kalam|gloria|handlee|sniglet|grandstander|lexend|outfit|unbounded|modak|monoton|sigmar|titan|luckiest|chango|dancing|satisfy|yellowtail|courgette|cookie|sacramento|fantasque|comic|pomodoro|marker|chalk|brush|script|hand|bubble|candy|jelly|cartoon/i
    // the fonts as fontconfig lists them, read again whenever the options open: Qt's own list is made once
    // when the shell starts and would never show a font installed later. Empty until the first read.
    property var systemFonts: []
    readonly property var fonts: {
        const source = systemFonts.length > 0 ? systemFonts : Qt.fontFamilies();
        const all = source.filter(f => !/symbols|material|awesome|icomoon|octicons|emoji|music|test|notation|nerd font mono|^noto (sans|serif) [a-z]/i.test(f) || /^noto (sans|serif)( display| cjk.*)?$/i.test(f)).filter(f => !/ mono$/i.test(f));
        const fun = all.filter(f => playful.test(f));
        const rest = all.filter(f => !playful.test(f));
        return fun.concat(rest);
    }

    // read the installed fonts again (a new font file is picked up by fontconfig's cache first)
    function rescanFonts() {
        if (!fontScan.running)
            fontScan.running = true;
    }

    Process {
        id: fontScan

        command: ["sh", "-c", "fc-cache >/dev/null 2>&1; fc-list : family | sed 's/,.*//' | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l.trim() !== "");
                if (list.length > 0)
                    root.systemFonts = list;
            }
        }
    }

    function setScale(id, scale) {
        update(id, {
            "scale": Math.max(0.5, Math.min(3, Math.round(scale * 10) / 10))
        });
    }

    // next style of the widget, in the order of its type
    function cycleStyle(id) {
        const item = items.find(i => i.id === id);
        const info = item ? typeInfo(item.type) : null;
        if (!info || info.styles.length < 2)
            return;
        const next = info.styles[(info.styles.indexOf(item.style) + 1) % info.styles.length];
        update(id, {
            "style": next
        });
    }

    function countOf(type) {
        return items.filter(i => i.type === type).length;
    }
}
