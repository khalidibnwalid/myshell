---
name: quickshell-ui-ux
description: The user's UI/UX preferences for the Settings window, launcher and panels in this Quickshell config. Use when designing or reviewing any page, row, popup, icon, empty state or default.
---

# UI/UX preferences (learned from the user)

## Show only what exists
- Hide pages, groups and rows for hardware or tools this computer does not have (no "No wired adapter" rows). Pages get an `available` flag in `Settings.qml`; the sidebar leaves them out.
- A momentary empty state of something that exists is fine ("Nothing is playing"). A permanent absence is not.
- Give an unavailable tool a note in README and `AboutPage` tools, not a row on the page.

## Icons
- Our own features use Material symbols (`MaterialSymbol`), never an icon looked up from the system theme.
- A result or row from another app shows that app's real icon (VS Code for its projects, the browser for its history, a provider app's own icon). A source that no app owns (recent files, your own commands, calculator) uses a symbol.
- The window/dock icon is the one exception: a real file (`assets/settings.svg`, installed by `scripts/install-settings-icon.sh`).
- Dropdown items can carry a logo via `image`; use it for app pickers.
- Previews: files in launcher results show a thumbnail, the image itself, or an album cover/video frame; other files a symbol matching their type.

## Defaults and control
- Defaults equal the user's current setup. "Reset" hands a value back to their own files; a master switch makes a feature read-only (values shown, nothing written).
- Mark unfinished features "Experimental" (badge in the header, flask icon in the sidebar, off by default).
- Native over invented: use the system's own mechanism (XDG autostart, `mimeapps.list` via `xdg-mime`, `hyprctl`, `gio`, `udisksctl`, GNOME search providers). Say honestly when Linux does not expose a hardware feature (e.g. the laptop's keyboard-light auto mode) and leave the hardware default alone until the user chooses.
- No formatting/destructive disk actions in Settings. Mount, unmount, eject only; system mounts cannot be unmounted.

## Layout
- One idea once. Do not repeat a figure in a bar and a row (memory used and free); put extras in the bar's note line. Summary page keeps the original look; "Detailed" adds the rest.
- Tabs look like tabs: one rounded bar, icon only except the open (or hovered) tab, which shows its name. A header block states what the tab is.
- An info icon only when the popup tells more than the row (a range, choices with values).
- An arrow beside a row opens an inner page when an option has its own settings (Files and folders).
- Sorting is drag and drop (`SortableList`), and the drag must not scroll the page.
- A typed number: clicking the number beside a slider turns it into an input.
- Dropdown for anything with a short fixed list of words; search box for long lists (fonts, apps).

## Wording
- Short, plain, second person. Say what it does and what it costs ("Asking an app that is not running may start it").
- Report honestly in chat: say when something was tested on the real machine and when it was not seen on screen.
