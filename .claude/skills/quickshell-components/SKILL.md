---
name: quickshell-components
description: Catalog of the reusable QML components in this repo with their properties. Use before building any Settings page, row, list, dropdown or gauge, so existing components are reused instead of rewritten.
---

# Reusable components (`components/` unless noted)

Pages and rows
- `SettingsPage` (`modules/Settings/pages/`): scrollable page. `title`, `subtitle`, `headerActions: [ ... ]` (right of the title), `leading: [ ... ]` (before the title, e.g. a logo). Children go in a centred column.
- `SettingGroup { title; actions }`: titled group; rounds the first and last visible child row, so rows may come and go. Use `visible:` on the group to hide it.
- `SettingRow { icon; title; description; image }`: label on the left; children are the controls on the right (a row of buttons, a switch, a dropdown).
- `SettingCard`: free-form card with the same surface; children stack in a column (use for custom content, grids, bars).
- `MeterRow` (`modules/Settings/pages/`): card with an icon, title, right-hand `detail`, a `Meter` bar (`value` 0-1, `barColor`) and a `note` line.
- `PageHeader`: back button + title for panel sub-pages (quick settings).

Controls
- `ToggleSwitch { checked; onToggled: on => }`.
- `PillButton { text; icon; toggled; onClicked }`, `IconButton { icon; size; iconSize; toggled; color }`.
- `Segmented { model: [{label, value}] or strings; value; onSelected }`: few choices side by side.
- `Dropdown { model: [{label, value, description, image}] or strings; value; placeholder; searchable; popupWidth; caption; icon; onSelected }`: `image` is a URL for a logo.
- `PillSlider { value (0-1); icon; onDragged: v => }` (do not bind `value` back inside `onDragged`). `Slider`, `VolumeSlider` exist too.
- `FieldInput { value; placeholder; icon; password; onCommitted(text); onEdited(text); onAccepted }`: commits only if the user typed.
- `ColorWell` (`modules/Settings/pages/`, click opens `ColorPicker { openWith(color, title); onPreviewed/onApplied/onCancelled }`).
- `SortableList { items: [{id, title, description, icon, image}]; onReordered: ids => }`: drag rows to reorder; keeps the page from scrolling.

Keyboard (see `quickshell-ui-ux`)
- `FocusRing { gap; radius; ringColor }`: put it inside a focusable control; it shows while the parent has `activeFocus`. `ringColor: Appearance.fgColor` on an accent-filled selected row.
- `ListNav { view; rowHeight; horizontal; onActivated; onTopReached }`: Home/End/PageUp/PageDown, Enter, and "Up on the first row" for a `ListView`/`GridView`. In the view: `Keys.onShortcutOverride: event => nav.override(event)` and `Keys.onPressed: event => nav.press(event)`. The arrows themselves are the view's (`keyNavigationEnabled`).
- `ClickAway {}`: last child of every app window; a passive `PointHandler` that takes the focus (and so the outline) away on any press without eating the click.
- `PillButton`, `IconButton` (Tab, Enter/Space, outline), `Segmented` (Tab, Left/Right choose), `FieldInput` already focusable. A new clickable `Rectangle`+`MouseArea` needs `activeFocusOnTab: true`, `Keys.onPressed` for Enter/Return/Space (accept it), `Keys.onShortcutOverride` accepting Space, and a `FocusRing {}`.

Display
- `Meter { value; fillColor }` thin bar. `RingGauge { icon; value; valueText; label; detail; color }`.
- `MaterialSymbol { icon; fill }` for every symbol. `StyledText` for all text. `HyprlandLogo { size; color }` tints the shipped SVG.
- `Tile`, `BigTile`, `ListRow`, `MediaCard`, `CalendarWidget`, `Segmented`, `ToggleButton` for the panels.

Hyprland rows
- `HyprOption { option }` (`modules/Settings/pages/`): one Hyprland option as a row. It builds only the control its type needs (`Loader` over toggle, choice, slider, colour, select, font, monitor, text) and an info popup built on first click. Options come from `HyprSettings.optionMap[name]`.

Services worth reusing
- `HyprSettings` (options, live values, `set/reset`, writing `quickshell.conf/.lua`), `SystemInfo`, `Search` + `SearchProviders` + `FilePreview`, `WindowManager` (`openSettings(page, query)`), `Keyboard`, `KeyboardLight`, `Printers`, `Storage`, `Drivers`, `DefaultApps`, `StartupApps`.

Rules of thumb
- Reuse a row/group/card before drawing a rectangle. Copy the radius logic only through `SettingGroup`.
- A list of rows from data: `Repeater { model: ...; delegate: SettingRow { required property var modelData } }` inside the group.
- Inline `component`s are fine in a page; a piece used by two pages becomes a file in `components/`.
