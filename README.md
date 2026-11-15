# Quickshell configuration

A Quickshell desktop shell configuration for Hyprland.

## Dependencies

The package names below are for Arch Linux and CachyOS.

### Required packages

Required packages:

- `quickshell` — runs the QML shell and brings in its Qt 6 and Wayland modules.
- `hyprland` — provides the compositor and `hyprctl` commands used for workspaces, keyboard layouts, and window focus. The Hyprland page reads every option from `hyprctl descriptions`, so use a version that has it (0.50 or newer). Both the hyprlang (`.conf`) and the Lua (`hyprland.lua`, 0.55 and newer) formats are supported.
- `networkmanager` — provides `nmcli` for Wi-Fi controls.
- `bluez` — provides Bluetooth support. `busctl` from `systemd` reads Bluetooth signal strength.
- `pipewire`, `pipewire-audio`, and `wireplumber` — provide audio devices and routing. Add `pipewire-pulse` for PulseAudio compatibility with other applications.
- `upower` — provides battery and power-profile information.
- `swaybg` — applies the shared desktop and lock screen wallpaper.
- `procps-ng` — provides `pkill` so wallpaper changes replace the previous `swaybg` process.
- `brightnessctl` — controls display backlight brightness.
- `xdg-utils` — provides `xdg-open` for opening files and web links, and `xdg-mime` and `xdg-settings` for the default apps.
- `glib2` — provides `gio`, which reads the default apps and the thumbnails shown in launcher results.
- `bc` — provides calculator results in the launcher.
- `wl-clipboard` and `cliphist` — record the clipboard history shown by the clipboard menu.
- `slurp` and `grim` — select an area and take the screenshot.
- `wl-screenrec` — records the selected area.
- `hyprpicker` — picks a colour from the screen.
- `libnotify` — provides `notify-send` for the capture notifications.
- `wtype` — pastes the picked clipboard item into the focused window.
- `ttf-material-symbols-variable` — provides the interface icon font.
- `adwaita-fonts` — provides the configured text font.
- `adwaita-icon-theme` — supplies application and system icons.

The standard Arch base packages provide shell tools used by the configuration, including `sh`, `awk` (`gawk`), `cat`, `df` (`coreutils`), `find` (`findutils`), `head`, `sed`, `sleep`, `lscpu` (`util-linux`), and `systemctl`/`busctl` (`systemd`).

### Optional system information tools

These optional packages enable additional hardware readings on the System Info page. Without them, those readings are unavailable.

- `lm_sensors` — provides `sensors` for temperature readings. Support depends on the hardware and sensor configuration.
- `pciutils` — provides `lspci` for graphics-device identification.

### Optional launcher tools

- `python` — runs the launcher sources for recent files, VS Code projects and browser history (standard library only).
- `ffmpegthumbnailer` — makes album covers and video frames for file previews in the launcher.
- `systemd` — `busctl` asks apps that offer their own results (GNOME search providers, installed by apps such as Files, Calculator and Firefox).
- `gtk3` — `gtk-update-icon-cache` refreshes the icon cache so the Settings window's gear icon shows.

### Optional hardware pages

Pages for hardware or tools that are missing are hidden.

- `cups` — Settings → Printers (queues, default printer, test page). Add `sane` for scanners.
- `udisks2` — Settings → Storage mounts, unmounts and ejects drives. `smartmontools` adds drive health, which needs administrator rights.
- `nvidia-utils` — GPU details (usage, memory, power) for NVIDIA cards, in Settings → System → Detailed.
- `chwd` (CachyOS) — shows the installed hardware profile in Settings → System → Detailed.
- `brightnessctl` — also drives the keyboard backlight, when the laptop has one.

### Optional settings tools

- `hyprsunset` — running in the background, it enables the night light controls in Settings → Display.
- `matugen` — enables "Match the wallpaper" in Settings → Appearance.

### Services and hardware

Network, Bluetooth, audio, and power controls require their corresponding system services to be running. On a typical system, enable NetworkManager and BlueZ with:

```sh
sudo systemctl enable --now NetworkManager bluetooth
```

PipeWire, WirePlumber, and UPower should also be available to the user session. Backlight control requires a supported backlight device and suitable permissions. Wi-Fi, Bluetooth, battery, and temperature features naturally depend on compatible hardware.

### Idle lock and wallpaper

The shell includes its own idle monitor and Wayland session lock. It authenticates through the system PAM `login` service and defaults to locking after 5 minutes, with displays turning off after 10 minutes. Configure the timers in Settings → Lock & idle. The Quick Settings footer can pause auto-lock for an hour without changing the saved settings. `Super + L` locks immediately.

Choose a wallpaper in Settings → Appearance. The selected image is shared by the desktop and lock screen.

### Settings window

Open it from the Quick Settings footer, or bind a key to `qs ipc call settings toggle` (also `open`, `close`, and `page <name>`, e.g. `page appearance`). Changes you make there are kept in `config.overrides.json` (generated and git-ignored), so the hand-written `config.json` stays the base; Settings → About lists any missing command-line tools.

### Keyboard layouts

Settings → Keyboard edits the layouts, their variants and the switching shortcut. Apply changes them in the running Hyprland session and writes them to `~/.config/hypr/config/keyboard.conf`; the first Apply also adds `source = ~/.config/hypr/config/keyboard.conf` to `hyprland.conf` (after the window rules) so they are used on the next start. That file is overwritten by Settings, and it takes precedence over `kb_layout`, `kb_variant` and `kb_options` in `input.conf`. On a laptop with a keyboard backlight it also sets the light's level and can turn it off when idle; until you pick a level the laptop's own auto mode is left alone.

### Hyprland

Settings → Hyprland lists every option of the installed Hyprland, with its description, range and choices, taken from `hyprctl descriptions`. Changes apply at once and are written to `~/.config/hypr/config/quickshell.conf` (and `quickshell.lua` for the Lua format); the first change adds `source = ~/.config/hypr/config/quickshell.conf` to `hyprland.conf` (or a `dofile` to `hyprland.lua`), after your own files so the values you change win. Your own files are never edited: reset one value, reset all, or switch the page to read-only to leave Hyprland to them. The active border and the border of grouped windows follow the accent colour (it can be turned off).

### Launcher

Settings → Launcher chooses where results come from (apps, Settings, files, web) and in which order (drag to sort). Settings is an app in the launcher, and its pages and Hyprland options are results. Apps that offer results through the GNOME search-provider interface are asked, and recent files, VS Code projects and browser history are built-in sources; any command can be added as a source (it gets the typed words as `$1` and prints `title`, a tab, `detail`, a tab, `what to open`). File names are looked up as you type (no index): choose the folders to look in or leave out, hidden files and the depth under Files and folders.

### Startup and default apps

Settings → Startup apps lists the XDG autostart entries your session starts (`~/.config/autostart` and `/etc/xdg/autostart`, started by uwsm) and switches them on or off the way the autostart specification says, with a `Hidden=true` file of the same name. Added apps are written there too. What Hyprland starts itself (`exec-once`) is listed but not changed. Settings → Default apps reads and sets `mimeapps.list` through `gio` and `xdg-mime`.

### Autocomplete

Settings → Autocomplete (experimental, off by default) turns on word suggestions while typing in any app. The words for the keyboard layout in use show under the pointer, next to the text cursor, or in the corner of the window (your choice); `Tab` and `Shift + Tab` put the next or previous one into the text, `Escape` closes them and restores what was typed.

- A small helper, `helpers/ime/qs-ime.c`, registers as the Wayland input method. It is built into `~/.cache/quickshell/ime` the first time the feature is turned on, which needs a C compiler, `wayland-scanner` and the `wayland`, `libxkbcommon` and `pango` headers (`base-devel`, `wayland`, `libxkbcommon` and `pango` on Arch).
- Only one input method can run at a time, so it does not work next to fcitx5 or ibus.
- Word lists (the 200,000 most frequent words per language, seen at least 15 times, from the FrequencyWords project) are downloaded with `curl` into `~/.local/share/quickshell/autocomplete` the first time a layout's language is used.
- Password fields are never read, and blocked apps (terminals by default) are left alone entirely. Nothing that is typed leaves the computer.
- `qs ipc call autocomplete toggle` (also `enable`, `disable`, `status`) switches it from a key bind.
