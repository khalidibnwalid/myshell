#!/bin/sh
# Makes the main Hyprland config include the files the Settings window writes.
# usage: apply-hyprland.sh HYPR_DIR
# hyprland.conf gets `source = …/quickshell.conf` as its last line; hyprland.lua (the
# newer format) gets a dofile() of quickshell.lua. Each is added once.
dir=$1
[ -d "$dir" ] || exit 1
mkdir -p "$dir/config"

conf="$dir/hyprland.conf"
if [ -f "$conf" ] && ! grep -qF 'config/quickshell.conf' "$conf"; then
    printf '\n# Hyprland settings made in the quickshell Settings window (kept last so they win)\nsource = ~/.config/hypr/config/quickshell.conf\n' >> "$conf"
fi

lua="$dir/hyprland.lua"
if [ -f "$lua" ] && ! grep -qF 'config/quickshell.lua' "$lua"; then
    printf '\n-- Hyprland settings made in the quickshell Settings window (kept last so they win)\ndofile("%s/config/quickshell.lua")\n' "$dir" >> "$lua"
fi
