# Quickshell configuration

A Quickshell desktop shell configuration for Hyprland.

## Dependencies

The package names below are for Arch Linux and CachyOS.

### Required packages

Required packages:

- `quickshell` — runs the QML shell and brings in its Qt 6 and Wayland modules.
- `hyprland` — provides the compositor and `hyprctl` commands used for workspaces, keyboard layouts, and window focus. The Hyprland page reads every option from `hyprctl descriptions`, so use a version that has it (0.50 or newer). Both the hyprlang (`.conf`) and the Lua (`hyprland.lua`, 0.55 and newer) formats are supported.
- `networkmanager` — provides `nmcli` for Wi-Fi controls.
- `bluez` — provides Bluetooth support. `busctl` from `systemd` reads Bluetooth signal strength, and `udevadm` from `systemd` reports the camera switch.
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
- `ffmpeg` (with `ffprobe`) — the Audio player reads tags and makes covers with it. `python-gobject` lets it appear as an MPRIS player.
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

### Optional capture tools

- `tesseract` and `tesseract-data-eng` — "Extract text" in the screenshot selector reads the words in the chosen area. Add `tesseract-data-ara` or another language package for more languages, then set them in Settings → Clipboard & capture (for example `eng+ara`).
- `zbar` — provides `zbarimg`, which reads QR codes for the QR option of the screenshot selector.

### Optional settings tools

- `hyprsunset` — running in the background, it enables the night light controls in Settings → Display.
- `matugen` — enables "Match the wallpaper" in Settings → Appearance.
- `gnome-control-center` — the "Add or remove accounts" button in Settings → Accounts opens its online accounts window. Existing accounts are listed without it.

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

### Notepad

A small notes app in `apps/Notepad/`: a list of notes on the left (pinned first, then the latest; drag its edge to change the width, hover a note for an `x` that deletes it, drag a note to put it where you want; pinned notes stay first and new notes start at the top), the editor on the right, a search box, and open, save, copy, pin and delete under the editor. Notes are saved as you type in `~/.local/share/quickshell/notepad/notes.json`; the first line is the title.

- Open it with `qs ipc call notepad toggle` (also `open`, `close`, `create` for a new note, `openFile <path>`), or bind `bind = $mainMod, N, global, quickshell:notepad`. It is also in the launcher and the dock.
- `Ctrl + N` makes a note, `Ctrl + F` searches, `Ctrl + B` folds the list away, `Ctrl + Shift + V` switches between Edit (write) and View (the note shown as Markdown: headings, lists, code, tables, links), `Ctrl + O` opens a text file as a note, `Ctrl + S` saves the note to the file it came from (or asks where), `Ctrl + Shift + S` always asks. Opening a file does not change it until you save.
- It lists itself as an app for plain text and Markdown files, so it appears in Settings → Default apps → Text and code; pick it there to make it the default for text files.
- It opens as a floating window like Settings; the rule for that is in the Hyprland window rules (`class = "dev.noctalia.noctalia-qs", title = "^(Notepad)$"`).

### Camera message

When the laptop's camera switch cuts or restores the camera, the shell shows "Camera on" or "Camera off". The switch disconnects the camera from USB, and `udevadm monitor` (from `systemd`) reports that, so nothing is polled and no key bind is needed.

### Emoji and symbols

The clipboard menu (`Super + V`) has a smiley button next to the search box that switches it to an emoji and symbol picker: tabs for the groups (recent, smileys, people, animals, food, activities, travel, objects, symbols, flags and text symbols such as arrows and Greek letters), a search by name or keyword, and a click or `Enter` pastes the pick into the window you came from (the menu remembers that window and refocuses it, so a click pastes too, as it does for the clipboard items). The arrow keys move over the grid and `Tab` changes the group. To open it directly, bind `bind = $mainMod, semicolon, global, quickshell:emoji`. The list is `assets/emoji.json` (made from the gemoji data, MIT); the recently used ones are in `~/.local/share/quickshell/emoji-recent.json`.

### Processes

A task manager in `apps/Processes/`: every running program with its CPU and memory use, grouped by program (a browser's many helpers become one row) or listed one by one, only yours or everyone's, a search, and a click on a column title sorts by it. Pick a row and press `Delete` (or the buttons in the title bar) to end it; Force quit stops it at once. The shell itself, Hyprland and the first process cannot be ended from here, and processes of other users need administrator rights. Nothing runs while the window is closed.

- Open it with `qs ipc call processes toggle` (also `open`, `close`), or bind `bind = $mainMod, Escape, global, quickshell:processes`. It is also in the launcher, the dock, and the memory tile of Quick Settings opens it (the processor tile opens Settings → System in its Detailed look, the storage tile Settings → Storage).
- It opens as a floating window like Settings (`title = "^(Processes)$"` in the Hyprland window rules).

### Audio

A player in `apps/Audio/`. It indexes the folders you give it (`~/Music` to start; Folders in the sidebar adds or removes more, subfolders included) and shows the tracks, albums and artists, favourites and recently played. Tracks are read once with `ffprobe` (tags, length) and `ffmpeg` (the cover: the picture inside the file, a frame of a video, or `cover.jpg`/`folder.jpg` beside it) and again only when the file changes. The index is in `~/.local/share/quickshell/audio/library.json`, the covers in `~/.cache/quickshell/audio/`, and the queue, the place in the track, volume, shuffle, repeat and speed in `player.json` next to it, so it carries on after a restart. The sound comes from Qt Multimedia, so it plays on while the window is closed.

- A queue you reorder by dragging, shuffle, repeat (off, all, one), speed 0.75 to 2, a sleep timer that fades out, and lyrics shown in time from a `.lrc` file with the same name beside the track (or the lyrics tag of the file); click a line to jump to it.
- It is an MPRIS player (`apps/Audio/scripts/mpris.py`, needs `python-gobject` for `/usr/bin/python3`): Quick Settings' media card, `playerctl` and the media keys show and control it, with the track list, seeking, volume, shuffle and loop. If the helper cannot start the rest still works.
- Open it with `qs ipc call audio toggle` (also `open`, `close`, `playpause`, `play`, `pause`, `next`, `previous`, `stop`, `openFile <path>`, `enqueue <path>`, `volume <0-100>`, `status`), or bind `bind = $mainMod, M, global, quickshell:audio`; `audioPlayPause`, `audioNext` and `audioPrevious` are shortcuts too. It is also in the launcher and the dock, plays files dropped on the window and is offered for audio files (Settings → Default apps).
- Keys: `Space` play/pause, `Left`/`Right` seek 5 s, `Up`/`Down` volume, `Ctrl+Left`/`Ctrl+Right` previous/next, `Ctrl+F` search, `Ctrl+L` lyrics, `Ctrl+J` queue, `Ctrl+B` sidebar, `Ctrl+O` open files, `Ctrl+Shift+S` shuffle, `Ctrl+R` repeat.
- It opens as a floating window like Settings (`title = "^(Audio)$"` in the Hyprland window rules).

### Timer

Countdown timers and a stopwatch in `apps/Timer/`. Pick a time (1 minute to 1 hour) or type one (`5:30`, `90` minutes, `1h 30m`, `45s`) with an optional name; run as many timers as you like, pause, restart or remove each, and a finished one rings with a notification and a sound (`canberra-gtk-play`, or `paplay` as the fallback). Timers are end times kept in `~/.local/share/quickshell/timer/timers.json`, so they go on while the window is closed and across a restart, and nothing is polled. The stopwatch has laps.

- Open it with `qs ipc call timer toggle` (also `open`, `close`, `start 5m "tea"`), or bind `bind = $mainMod, T, global, quickshell:timer`. It is also in the launcher and the dock.
- It opens as a floating window like Settings (`title = "^(Timer)$"` in the Hyprland window rules).

### Keyboard layouts

Settings → Keyboard edits the layouts, their variants and the switching shortcut. Apply changes them in the running Hyprland session and writes them to `~/.config/hypr/config/keyboard.conf`; the first Apply also adds `source = ~/.config/hypr/config/keyboard.conf` to `hyprland.conf` (after the window rules) so they are used on the next start. That file is overwritten by Settings, and it takes precedence over `kb_layout`, `kb_variant` and `kb_options` in `input.conf`. On a laptop with a keyboard backlight it also sets the light's level and can turn it off when idle; until you pick a level the laptop's own auto mode is left alone.

### Bar styles

Settings → Appearance → Bar picks the look of the bar: Classic (one strip), Capsule (one rounded shape floating a little off the edge), Islands (workspaces, clock and status each in their own shape) or Inset (a solid bar with the desktop as a rounded sheet beside it). The bar can be on any edge. Every style takes the same room at the screen edge (50 px), so windows never move when the style changes: Capsule and Islands leave a 4 px gap to the screen edge and their shape fills the other 46 px.

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
