---
name: quickshell-glass-dialogs
description: The shell's glass dialog look (Quick Settings shape, background blur, pill tiles), the design rules the user set for it, and how to build a prompt, popup or file dialog with GlassDialog, including the Hyprland blur rule, an optional-module switch and how to check it on screen. Use when adding a prompt, confirmation, overlay popup, file dialog or any new panel, or restyling one.
---

# Glass dialogs

The look the user chose for the polkit prompt (and wants for new popups): the **shape of the Quick Settings panel**, with the **compositor blurring only the panel**. It is the `GlassDialog` component (`components/GlassDialog.qml`); do not redraw it.

## The recipe (what GlassDialog already does)
- Panel: `radius: 36` (= inner radius 20 + padding 16), colour `Qt.alpha(Appearance.bgColor, Math.max(0.35, Appearance.panelAlpha))`, 1px `Appearance.hairlineColor` border, 16px padding, 10px between children, width 380.
- Header tile: `radius: 20`, fill `Appearance.surfaceColor`; a 48px round accent badge with a symbol (`accentContrastColor` on `accentColor`), a 15px DemiBold title, a 12px muted message.
- Fields and buttons are **pills**: 54px high, `radius: height / 2`, fill `surfaceColor` (`surfaceHighColor` while focused or hovered), no border until there is an error (then a 1.5px `accentColor` border). Submit = a 40px accent circle with `arrow_forward`, shown only once there is input.
- Buttons are `PillButton`s in one row, equal width (`compact`: 120px each, right-aligned, with the `footer` controls on the left); the primary is `toggled` (accent). A failed input shakes the panel (`shake()`).
- Fade and scale in (0.96 to 1, `animNormal`, `easeOut`). No full-screen dim, no screen blur: only the panel is blurred. The user explicitly did not want an overlay blur; a blurred wallpaper or opaque card was rejected as "ugly" next to the bar and Quick Settings.
- Use only theme tokens (`Appearance.*`), `StyledText`, `MaterialSymbol`; never hard-coded colours.

## Using it
```qml
PanelWindow {                       // a full-screen overlay window for a prompt
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "quickshell-<name>"      // needs the blur rule below
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent }                // transparent; keeps clicks off the windows below

    GlassDialog {
        anchors.centerIn: parent
        icon: "lock"; title: "..."; message: "..."
        buttons: [{ text: "Cancel", key: "cancel" }, { text: "OK", key: "ok", primary: true, enabled: ready }]
        onButtonClicked: key => ...
        // children go between the header and the buttons (Layout.fillWidth: true)
    }
}
```
- Inside a Settings or app window use `ModalDialog` (a `Popup`); `GlassDialog` is for layer-shell overlays and panels.
- `buttons` is rebuilt when a binding inside it changes (`enabled: field.canSubmit`), which is fine for a few buttons.
- Ids of the instance's children (e.g. `field`) can be used in `buttons:` and handlers, since they live in the same file.

## Layout by case (pick the case first, then copy the closest implementation)
The look is the same everywhere; the **layout is not**. An authentication prompt is small and focused, a picker is wide and tool-like. Decide which case you have before drawing anything.

| Case | Width / header | Body | Buttons | Keys and focus | Copy from |
|---|---|---|---|---|---|
| **Authentication / secret prompt** (password, PIN, token) | 380, regular header (48px badge, title, the reason as message) | one pill field with a submit arrow, one status line (error in accent, hints muted); nothing else | Cancel + the verb ("Authenticate"), equal width, primary disabled until there is input | field focused on open, Enter submits, Esc cancels, wrong input shakes and clears; text hidden unless the system asks to show it | `modules/Polkit/` |
| **Confirmation** (delete, discard, replace) | 380, regular header with a fitting symbol | the consequence in one or two sentences, and whether it can be undone | Cancel + a **verb that names the action** ("Delete", never "OK"); a destructive confirm does not take Enter by default | Cancel has the focus for destructive actions; Esc cancels | `components/GlassDialog.qml` header + `buttons` only |
| **Picker** (files, apps, colours, emoji) | 720-800, **compact** header (one line, source app at the right) | a toolbar row (up/back, path, **search box**, view and hidden toggles), then a sidebar of places (170px, `fillWidth: false`) beside a scrolling list in a radius-20 surface tile (about 340px high) | Cancel + the verb ("Open", "Save", "Select") at 120px, right-aligned; filters and options in the `footer` on the left | list focused on open; arrows, Enter opens or accepts, Backspace goes up, Ctrl+G rows/tiles; selecting by click and by keys must agree; an empty folder says so | `modules/FileChooser/` |
| **Form** (a few settings or fields) | 420-480, regular header | labelled rows: `FieldInput` pills, `ToggleSwitch`, `Segmented`; validation text under the field, not in a popup | Cancel + Save/Apply; primary disabled while invalid | first field focused, Tab order top to bottom, Enter in the last field submits | `modules/Settings/pages/` rows |
| **Choice list** (pick an account, device, identity) | 420, regular header | one tile per choice (icon, name, muted detail), radius-20 `surfaceColor`, the current one accent-tinted | Cancel + Select; double click or Enter picks | arrows move, current item selected on open | the places list in `FileChooserWindow.qml` |
| **Progress / information** | not a dialog: use a notification, an OSD or a status line | - | - | - | `modules/Notifications/`, `modules/OSD/`; a modal one only when nothing else may happen meanwhile (header + `Meter` + Cancel) |

Sizing and spacing rules that hold for every case:
- Three widths only: **380** (prompt, confirmation), **420-480** (form, choice list), **720-800** (picker). Do not invent a fourth.
- Between the header and the buttons: at most **three stacked rows** for a prompt; a picker has a toolbar row, the body, and nothing else (put extras in the `footer`).
- Long content scrolls **inside a surface tile**, never grows the dialog; keep it under about 80% of the screen height.
- Sections are separated by tiles and the 10px gap, not by divider lines or extra borders.
- Header: regular for small dialogs (the badge is the visual anchor), `compact` for wide ones; the message is the reason or the source, never a repeat of the title.
- The primary button is always the right-most and names the action; the cancel button is always present and always `key: "cancel"` (Esc sends the same).
- Overlay windows (anything that blocks) take exclusive keyboard focus and a transparent click-catcher; in-window dialogs use `ModalDialog`.
- Every case has: an initial focus, an Esc path, a failure state (shake or accent text), and an empty or disabled state. Check all four before calling it done.

## Design rules (the user's feedback, in the order it came)
1. **Match the bar and Quick Settings.** Same shape language: radius 36 panel, radius 20 tiles, pills. An opaque card, a dimmed or blurred full screen, or a wallpaper backdrop was called "ugly" next to them. Start from `GlassDialog`; if it cannot express the design, extend it, do not draw a one-off panel.
2. **Blur only the panel.** The user liked "the bg blur" (the panel's own background blur) and rejected the overlay blur. No dim layer.
3. **Slim headers.** A tall header tile in a big dialog was "weird and big": use `compact: true` (34px badge, title and app name on one line) for anything wider than a prompt.
4. **Secondary controls live in the footer row**, left of the buttons (`footer: [ ... ]`), not on rows of their own (filters, "remember this", a count). Fewer stacked rows is the goal.
5. **Pictures where there are pictures.** A file list shows image thumbnails (`FileThumb`) and offers a grid; remember the choice in config, add a keyboard shortcut (Ctrl+G), keep both views working with the keyboard.
6. **Say what the user gets, not the mechanism.** Settings text: "Use the shell's own password prompt", "Use the shell's own file dialogs" (not "register as a polkit agent"). One short sentence per state; the off text says what takes over.
7. **Real data, never mock text.** A line like "(3 minutes left to unlock)" came from PAM (`pam_faillock`), and the user asked if it was a mock. Show system messages as given and, when asked, say where they come from.
8. **Honest limits.** Native toolkit dialogs (GTK message boxes of VS Code, Firefox) cannot be restyled from here; say so and offer the real options (`window.dialogStyle: custom`, a portal backend for file pickers) instead of promising it.

## Second user: the file chooser portal
`modules/FileChooser/` draws the open/save dialogs of other apps. `FileChooser.qml` = scope, helper process, request queue; `FileChooserWindow.qml` = the dialog (state, search, toolbar, name field, footer, shortcuts); `FileEntries.qml` = the rows/tiles and their keyboard (reports with signals); `FilePlaces.qml` = the sidebar; `FileThumb.qml` = thumbnail or type symbol. Split a window like this when it passes ~500 lines: a component per visual block that owns its keyboard, the window keeps the state and decides what events mean. It is a `GlassDialog` (780 wide, `compact`) with a path bar, places, a list or tile view of a `FolderListModel`, a name field when saving, and the filters in the `footer`. Fed by `helpers/portal-filechooser` over stdin/stdout JSON lines (the `audio-mpris` pattern). Namespace `quickshell-filechooser`, blur rule next to the polkit one. Switches: `fileChooser.enabled` (default on), `fileChooser.grid` (default off).
- Modes: `open`, `save`, `savefiles` (a folder; the app's names are added), `directory`, `multiple`. Return absolute paths; the helper turns them into `file://` URIs. Escape cancels; Enter in folder mode with nothing picked accepts the current folder; Ctrl+G rows/tiles, Ctrl+H hidden files.
- Thumbnails: `Image { sourceSize: Qt.size(2 * size, 2 * size); asynchronous: true; cache: false }` only for image extensions (png, jpg, jpeg, gif, webp, svg, bmp, ico); decode at the shown size, never the photo's size. Fall back to the type symbol until it is ready.
- `FolderListModel` (`import Qt.labs.folderlistmodel`): roles `fileName`, `filePath`, `fileIsDir`, `fileSize`; `get(i, "filePath")`, `isFolder(i)`, `count`; `nameFilters` takes globs only (a mime-only filter shows everything); `showDirsFirst`, `showHidden`, `caseSensitive: false`.

## Keyboard and accessibility of a picker (required, not optional)
Every picker must be fully usable without a mouse, with the shared components from `quickshell-ui-ux`:
- **Type to search**: `TypeToSearch { onTyped: text => search.append(text) }`, and `ahead.press(event)` in the dialog's `Keys.onPressed` for keys no control took. The search box filters the current folder by words in the name; Enter opens the first match, Down goes into the list, Escape clears the search first and only then cancels (`escapeKey`).
- **Lists**: `ListNav` (Home/End/PageUp/PageDown/Enter, Up on the first row goes back to the search box) with `Keys.onShortcutOverride` / `Keys.onPressed` in each view, a `FocusRing` on the current row (`visible: row.ListView.isCurrentItem && list.activeFocus`), selection by keys and by mouse must agree. The search works on a **filtered JS array** (`entries`), rebuilt from the `FolderListModel` on `onCountChanged` and when it becomes `Ready`; selection is by path so it survives a rebuild.
- **Sidebar of places**: one Tab stop (`activeFocusOnTab` on a wrapper item), Up/Down/Home/End move inside it, Enter/Space opens, a ring on the current place. Tab order follows the visual order: toolbar, places, files, name, filters, buttons.
- **Shortcuts**: Ctrl+L path, Ctrl+F search, Ctrl+G rows/tiles, Ctrl+H hidden, Ctrl+A select all (several files), Alt+Up and Backspace go to the parent. Backspace is `event.key === Qt.Key_Backspace` in `Keys.onPressed`; `Keys.onBackPressed` is the Android back key and never fires.
- **Pointer**: `ClickAway { target: dialog }` so typing works again after a click on the background.
- **Screen readers**: `Accessible.role` / `Accessible.name` on the dialog, the lists, the rows and tiles (name = "Folder x" / "File x", `Accessible.selected`), the places and the icon-only buttons (with their shortcut in the name).
- **Thumbnails** only for formats Qt can decode here: png, jpg, gif, svg, bmp, ico built in or by the installed plugins; webp/tiff only when `libqwebp` / `libqtiff` exist in the Qt imageformats folder (package `qt6-imageformats`), checked at dialog start; the rest show their type symbol, no log spam.
- **Test it with keys, not the mouse**: open with `portal_test.py ... folder=/home/khalid/Pictures`, then `wtype -k s -k c -k r` (typing searches), `-k Down`, `-k Return`, `-k BackSpace`, `-k Escape`, and screenshot after each step. Never rely on a single frame: the focus ring and the path bar show where you are.

## QML gotchas met while building these
- **Never name a component like a Quickshell or Qt type.** A local `FileView.qml` clashed with `Quickshell.Io.FileView` (imported in the same file) and the reload failed with the misleading `Cannot assign to non-existent property "onSomeSignal"` on the *last* signal handler. If a property or handler "does not exist" although it is declared, rename the component first (prefix it with the module: `FileEntries`, `FilePlaces`). Before naming one, `grep -rn "<Name>" /usr/lib/qt6/qml ~/.config/quickshell` and check the types of the modules the file imports (`Quickshell`, `Quickshell.Io`, `Quickshell.Widgets`, ...).
- Pass plain values through signals (`entryClicked(string path, bool isDir, int mods)`), not event objects; let the child accept its own key event and tell it the state it needs (`searching: query !== ""`), as `FileEntries` does for Escape.
- `Dropdown` and `ModalDialog` need an `ApplicationWindow`; inside a layer-shell `PanelWindow` use `Segmented`, `IconButton`, `FieldInput`, `PillButton`.
- A nested `ColumnLayout`/`RowLayout` has `Layout.fillWidth: true` by default and can squeeze its sibling to nothing: pin a sidebar with `fillWidth: false` + `preferredWidth` + `maximumWidth`.
- `FieldInput` shows its `value` again when editing ends: never set its inner text by hand. Bind `value` and take `onEdited`; to replace what the user typed, set `dirty = false` and change the bound property.
- An inline `component` cannot see ids of the file that holds it: make a small file (`FileThumb.qml`) and pass properties.
- Two views of one model (`ListView` + `GridView`): `visible` toggles which is shown; keep one `activeView`, reset both `currentIndex`es, and share the pick/enter logic in functions on the window.
- Children of a `GlassDialog` get `Layout.*`; its `buttons` entries are plain objects, so pass `enabled` through a binding.
- A key handler on the dialog (`Keys.onPressed`) receives keys that the focused list or field did not accept, which is how Ctrl+G works without stealing typing.
- Do not set `Component.onDestruction` to start a Process (the scope is already gone): react to the config value in an always-loaded scope instead (`onActiveChanged`), as `FileChooser.qml` does.

## Test client
`python3 -I .claude/skills/quickshell-glass-dialogs/portal_test.py open|save|dir [multiple] [folder=/path]` asks the real portal and prints the response. It must stay connected: a `gdbus call` exits at once, the portal sees the caller vanish and cancels the dialog. Send keys with `wtype -k Escape` / `-k Return` / `-M ctrl -k g -m ctrl` (the dialog has exclusive keyboard focus). A real app (Claude desktop uses the portal) is the final test.

## The blur rule (easy to forget)
Blur comes from Hyprland, not QML. Add a layer rule for the window's namespace in **`~/.config/hypr/config/windowrules.lua`** (user-owned), next to the others:
```lua
hl.layer_rule({ match = { namespace = "^quickshell-<name>$" }, blur = true, ignore_alpha = 0.01, animation = "fade" })
```
Not in `config/quickshell.lua`: Settings rewrites that file. A layer that has no rule shows the panel as a plain translucent rectangle. Do not add a dim behind the dialog: with `ignore_alpha = 0.01` anything over 1% alpha is blurred, so a dim would blur the whole screen.

## Optional modules
Anything that takes over a system job (the polkit agent, the file chooser portal) gets `<section>.enabled` in `config/Config.qml` (a `JsonObject`, default as the user wants it, name added to `objectSections`), an entry in `config.schema.json`, a `SettingRow` + `ToggleSwitch` on a Settings page, and in `shell.qml` it is loaded through `LazyLoader { active: Config.<section>.enabled; ... }` so that off really unloads it (the polkit agent then unregisters and another agent can run). Mention it in README. Default: what the user asks for (polkit and the file chooser are on). A module that writes system files (portal config) writes them on enable, removes them on disable, never overwrites a file that is not its own, and keeps a working fallback while the shell is not running.

## Checking it
- Quickshell reloads on file saves, but a prompt only exists while something asks. Trigger the polkit one with `pkexec true` (cancel it; nothing runs), the file chooser with `portal_test.py`, and take the screenshot while it is open: `(timeout 12 pkexec true >/dev/null 2>&1 &); sleep 4; grim /path/shot.png`, then read the image. `hyprctl layers | grep quickshell-<name>` tells whether the window exists at all.
- A screenshot that shows the previous design means the reload had not happened yet: touch the file, wait 6 s, trigger again. The user's own screenshots can show the old version for the same reason; compare before arguing.
- Read `qs log` for QML errors, from the bottom: old `ERROR ... is not a type` lines stay in the log after a good reload.
- **Never submit a password in a test.** Three wrong tries lock the account for 10 minutes (`pam_faillock`: `faillock --user $USER` lists them; `sudo faillock --user $USER --reset` clears, which is the user's call). It blocks sudo and polkit too. Test with Cancel/Escape and say the password path was not tested.
- Say in chat what you saw on screen and what you could not test (typing a real password, the wrong-password shake, a real click).
