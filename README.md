# Quickshell configuration

A Quickshell desktop shell configuration for Hyprland.

## Dependencies

The package names below are for Arch Linux and CachyOS.

### Required packages

Required packages:

- `quickshell` — runs the QML shell and brings in its Qt 6 and Wayland modules.
- `hyprland` — provides the compositor and `hyprctl` commands used for workspaces, keyboard layouts, and window focus.
- `networkmanager` — provides `nmcli` for Wi-Fi controls.
- `bluez` — provides Bluetooth support. `busctl` from `systemd` reads Bluetooth signal strength.
- `pipewire`, `pipewire-audio`, and `wireplumber` — provide audio devices and routing. Add `pipewire-pulse` for PulseAudio compatibility with other applications.
- `upower` — provides battery and power-profile information.
- `swaybg` — applies the shared desktop and lock screen wallpaper.
- `procps-ng` — provides `pkill` so wallpaper changes replace the previous `swaybg` process.
- `brightnessctl` — controls display backlight brightness.
- `xdg-utils` — provides `xdg-open` for opening files and web links.
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

Open it from the Quick Settings footer, or bind a key to `qs ipc call settings toggle` (also `open`, `close`, and `page <name>`, e.g. `page appearance`). Everything changed there is written to `config.json`; Settings → About lists any missing command-line tools.
