---
name: quickshell-glass-dialogs
description: The shell's glass dialog look (Quick Settings shape, background blur, pill tiles) and how to build a prompt or popup in it with GlassDialog, including the Hyprland blur rule, an optional-module switch and how to check it on screen. Use when adding a prompt, confirmation, overlay popup or any new panel, or restyling one.
---

# Glass dialogs

The look the user chose for the polkit prompt (and wants for new popups): the **shape of the Quick Settings panel**, with the **compositor blurring only the panel**. It is the `GlassDialog` component (`components/GlassDialog.qml`); do not redraw it.

## The recipe (what GlassDialog already does)
- Panel: `radius: 36` (= inner radius 20 + padding 16), colour `Qt.alpha(Appearance.bgColor, Math.max(0.35, Appearance.panelAlpha))`, 1px `Appearance.hairlineColor` border, 16px padding, 10px between children, width 380.
- Header tile: `radius: 20`, fill `Appearance.surfaceColor`; a 48px round accent badge with a symbol (`accentContrastColor` on `accentColor`), a 15px DemiBold title, a 12px muted message.
- Fields and buttons are **pills**: 54px high, `radius: height / 2`, fill `surfaceColor` (`surfaceHighColor` while focused or hovered), no border until there is an error (then a 1.5px `accentColor` border). Submit = a 40px accent circle with `arrow_forward`, shown only once there is input.
- Buttons are `PillButton`s in one row, equal width; the primary is `toggled` (accent). A failed input shakes the panel (`shake()`).
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

## The blur rule (easy to forget)
Blur comes from Hyprland, not QML. Add a layer rule for the window's namespace in **`~/.config/hypr/config/windowrules.lua`** (user-owned), next to the others:
```lua
hl.layer_rule({ match = { namespace = "^quickshell-<name>$" }, blur = true, ignore_alpha = 0.01, animation = "fade" })
```
Not in `config/quickshell.lua`: Settings rewrites that file. A layer that has no rule shows the panel as a plain translucent rectangle. Do not add a dim behind the dialog: with `ignore_alpha = 0.01` anything over 1% alpha is blurred, so a dim would blur the whole screen.

## Optional modules
Anything that takes over a system job (like the polkit agent) gets `<section>.enabled` in `config/Config.qml` (a `JsonObject`, default as the user wants it, name added to `objectSections`), an entry in `config.schema.json`, a `SettingRow` + `ToggleSwitch` on a Settings page, and in `shell.qml` it is loaded through `LazyLoader { active: Config.<section>.enabled; ... }` so that off really unloads it (the polkit agent then unregisters and another agent can run). Mention it in README. Polkit: default on.

## Checking it
- Quickshell reloads on file saves, but a prompt only exists while something asks. Trigger the polkit one with `pkexec true` (cancel it; nothing runs), and take the screenshot while it is open:
  `(timeout 12 pkexec true >/dev/null 2>&1 &); sleep 4; grim /path/shot.png`, then read the image. Do not `pkill -f "pkexec true"` from the same command: it kills the shell running it.
- Read `qs log` for QML errors. If a screenshot shows the previous design, the reload had not happened yet: touch the file, wait, trigger again.
- Say in chat what you saw on screen and what you could not test (typing a real password, the wrong-password shake).
