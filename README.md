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
- `brightnessctl` — controls display backlight brightness.
- `xdg-utils` — provides `xdg-open` for opening files and web links.
- `bc` — provides calculator results in the launcher.
- `wl-clipboard` and `cliphist` — record the clipboard history shown by the clipboard menu.
- `wtype` — pastes the picked clipboard item into the focused window.
- `ttf-material-symbols-variable` — provides the interface icon font.
- `adwaita-fonts` — provides the configured text font.
- `adwaita-icon-theme` — supplies application and system icons.

The standard Arch base packages provide shell tools used by the configuration, including `sh`, `awk` (`gawk`), `cat`, `df` (`coreutils`), `find` (`findutils`), `head`, `sed`, `sleep`, `lscpu` (`util-linux`), and `systemctl`/`busctl` (`systemd`).

### Optional system information tools

These optional packages enable additional hardware readings on the System Info page. Without them, those readings are unavailable.

- `lm_sensors` — provides `sensors` for temperature readings. Support depends on the hardware and sensor configuration.
- `pciutils` — provides `lspci` for graphics-device identification.

### Services and hardware

Network, Bluetooth, audio, and power controls require their corresponding system services to be running. On a typical system, enable NetworkManager and BlueZ with:

```sh
sudo systemctl enable --now NetworkManager bluetooth
```

PipeWire, WirePlumber, and UPower should also be available to the user session. Backlight control requires a supported backlight device and suitable permissions. Wi-Fi, Bluetooth, battery, and temperature features naturally depend on compatible hardware.
