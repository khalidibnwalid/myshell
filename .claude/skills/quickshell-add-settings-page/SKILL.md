---
name: quickshell-add-settings-page
description: Step by step recipe for adding a Settings page backed by a service in this Quickshell config, including registration, hiding when hardware is missing, search keywords, README and About updates. Use when the user asks for a new settings page or section.
---

# Adding a Settings page

1. **Look at what the system already provides.** Prefer its native mechanism and check it on this machine first (run the command, read sysfs/D-Bus). Decide what is read-only and what can be changed without administrator rights. Do not invent a storage format when the system has one.
2. **Service** `services/Thing.qml` (singleton): state as properties, `refresh()`, actions as functions, parsing in `Process`+`StdioCollector` handlers. Arguments, not string pasting. Give an `available`/`present` flag when the hardware may be absent.
3. **Config** (only if the page has its own settings): default in `config/Config.qml`, schema in `config.schema.json`; read with `Config.x?.key ?? default`; write with `Config.setIn("section", "key", value)` for plain sections.
4. **Page** `modules/Settings/pages/ThingPage.qml`: `SettingsPage { title; subtitle; Component.onCompleted: Thing.refresh() }`, a `Timer` that polls only while the page exists, then `SettingGroup`s of `SettingRow`/`MeterRow`/`SettingCard`. Reuse components (see `quickshell-components`). Hide absent things with `visible:`.
5. **Register** in `modules/Settings/Settings.qml`: an entry in `pages` (`key`, `name`, `icon` (Material), `group`: Connections / Device / Personalisation / System, `keywords`, optional `"available": <binding>`, `component: thingPage`) and a `Component { id: thingPage; ThingPage {} }` block. The launcher finds the page through `WindowManager.settingsIndex` automatically.
6. **Startup behaviour**: if it must work before the page opens, call `Services.Thing.refresh()` in `shell.qml`.
7. **Docs**: add new commands to `README.md` (required or optional list) and to `AboutPage.qml`'s `tools` map; add a short README section for non-obvious behaviour.
8. **Verify** (see `quickshell-verify`), then report what was and was not seen.
9. **Commit**: `feat(scope): ...` with short bullets, on master, no trailer.

Variants
- Wraps Hyprland options: use `HyprOption { option: HyprSettings.optionMap["section:name"] }` rows, or point the user at the Hyprland page rather than duplicating it (the user removed pages that were only Hyprland options).
- Inner page: keep a `property string inner` on the page, switch `title`/`subtitle`, add a back `PillButton` in `headerActions`, and set `visible:` on the groups of each level.
