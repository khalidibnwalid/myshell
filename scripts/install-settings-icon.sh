#!/bin/sh
# Gives the Settings window a gear icon. The window belongs to the shell's program, which
# the system knows as "noctalia-qs" with the Noctalia logo; a desktop entry of the same id
# in the user's folder takes its place (it is hidden from launchers, as the original is).
# usage: install-settings-icon.sh SHELL_DIR
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
