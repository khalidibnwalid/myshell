#!/bin/sh
# Installs the icons and desktop entries of the shell's own apps.
# Settings: its window belongs to the shell's program, which the system knows as "noctalia-qs"
# with the Noctalia logo; a desktop entry of the same id in the user's folder gives it a gear
# instead (hidden from launchers, as the original is).
# Notepad: an app of its own, with an icon and a visible desktop entry so the launcher and the
# dock can find it.
# usage: install-app-icons.sh SHELL_DIR
dir=$1
data=${XDG_DATA_HOME:-$HOME/.local/share}
icon="$data/icons/hicolor/scalable/apps/quickshell-settings.svg"
entry="$data/applications/dev.noctalia.noctalia-qs.desktop"

[ -f "$dir/assets/settings.svg" ] || exit 1
mkdir -p "$(dirname "$icon")" "$(dirname "$entry")"
if ! cmp -s "$dir/assets/settings.svg" "$icon"; then
    cp "$dir/assets/settings.svg" "$icon"
    # an icon cache in the folder hides new icons until it is rebuilt (the shell sees the
    # icon from its next start on)
    command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$data/icons/hicolor" >/dev/null 2>&1
    touch "$data/icons/hicolor"
fi
want="[Desktop Entry]
Version=1.5
Type=Application
NoDisplay=true
Name=Settings
Icon=quickshell-settings"
[ "$(cat "$entry" 2>/dev/null)" = "$want" ] || printf '%s\n' "$want" > "$entry"

# Notepad: its window has the shell's app id too, so the dock tells it apart by its title
nicon="$data/icons/hicolor/scalable/apps/quickshell-notepad.svg"
nentry="$data/applications/quickshell-notepad.desktop"
if [ -f "$dir/apps/Notepad/notepad.svg" ]; then
    if ! cmp -s "$dir/apps/Notepad/notepad.svg" "$nicon"; then
        cp "$dir/apps/Notepad/notepad.svg" "$nicon"
        command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$data/icons/hicolor" >/dev/null 2>&1
        touch "$data/icons/hicolor"
    fi
    nwant="[Desktop Entry]
Version=1.5
Type=Application
Name=Notepad
Comment=Quick notes, saved as you type
Exec=\"$dir/apps/Notepad/open.sh\" %f
Icon=quickshell-notepad
Categories=Utility;TextEditor;
MimeType=text/plain;text/markdown;
Keywords=notes;note;memo;text;
Terminal=false"
    if [ "$(cat "$nentry" 2>/dev/null)" != "$nwant" ]; then
        printf '%s\n' "$nwant" > "$nentry"
        # so the system lists it among the apps that open text files (Settings → Default apps)
        command -v update-desktop-database >/dev/null && update-desktop-database "$data/applications" >/dev/null 2>&1
    fi
fi

# Processes: the same, an app of its own (it opens with `qs ipc call processes open`)
picon="$data/icons/hicolor/scalable/apps/quickshell-processes.svg"
pentry="$data/applications/quickshell-processes.desktop"
if [ -f "$dir/apps/Processes/processes.svg" ]; then
    if ! cmp -s "$dir/apps/Processes/processes.svg" "$picon"; then
        cp "$dir/apps/Processes/processes.svg" "$picon"
        command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$data/icons/hicolor" >/dev/null 2>&1
        touch "$data/icons/hicolor"
    fi
    pwant="[Desktop Entry]
Version=1.5
Type=Application
Name=Processes
Comment=See what is running and end it
Exec=qs ipc call processes open
Icon=quickshell-processes
Categories=System;Monitor;
Keywords=task manager;system monitor;kill;processes;
Terminal=false"
    [ "$(cat "$pentry" 2>/dev/null)" = "$pwant" ] || printf '%s\n' "$pwant" > "$pentry"
fi

# Timer: the same, an app of its own (it opens with `qs ipc call timer open`)
ticon="$data/icons/hicolor/scalable/apps/quickshell-timer.svg"
tentry="$data/applications/quickshell-timer.desktop"
if [ -f "$dir/apps/Timer/timer.svg" ]; then
    if ! cmp -s "$dir/apps/Timer/timer.svg" "$ticon"; then
        cp "$dir/apps/Timer/timer.svg" "$ticon"
        command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$data/icons/hicolor" >/dev/null 2>&1
        touch "$data/icons/hicolor"
    fi
    twant="[Desktop Entry]
Version=1.5
Type=Application
Name=Timer
Comment=Countdown timers and a stopwatch
Exec=qs ipc call timer open
Icon=quickshell-timer
Categories=Utility;Clock;
Keywords=timer;stopwatch;alarm;countdown;pomodoro;
Terminal=false"
    [ "$(cat "$tentry" 2>/dev/null)" = "$twant" ] || printf '%s\n' "$twant" > "$tentry"
fi
