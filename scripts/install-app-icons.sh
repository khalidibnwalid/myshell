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
    # quoted only when it has to be: xdg-open looks the first word up with the quotes still on
    nexec="$dir/apps/Notepad/open.sh"
    case $nexec in
        *[[:space:]\"\'\\\<\>~\|\&\;\$\*\?\#\(\)\`]*) nexec="\"$nexec\"" ;;
    esac
    nwant="[Desktop Entry]
Version=1.5
Type=Application
Name=Notepad
Comment=Quick notes, saved as you type
Exec=$nexec %f
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

# The other apps (apps/*/app.json: Processes, Timer, Audio…) are installed from their manifests, and the
# entry of one that is switched off is removed. usage: install-app-icons.sh SHELL_DIR [DISABLED_ID]...
shift
command -v python3 >/dev/null && python3 "$dir/scripts/install-apps.py" "$dir" "$@"
