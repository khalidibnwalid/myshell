#!/bin/sh
# Applies keyboard layouts to Hyprland and keeps them across restarts.
# usage: apply-keyboard.sh LAYOUTS VARIANTS OPTIONS HYPR_DIR
#   e.g. apply-keyboard.sh us,ara "" grp:alt_shift_toggle ~/.config/hypr
# The layouts are written to HYPR_DIR/config/keyboard.conf, which hyprland.conf sources
# (the line is added once if it is missing). With a Lua config (hyprland.lua, Hyprland
# 0.57) they go to keyboard.lua instead, which the config loads by hand, and `hyprctl eval`
# replaces `hyprctl keyword`.
layout=$1
variant=$2
options=$3
dir=$4
conf="$dir/config/keyboard.conf"
main="$dir/hyprland.conf"

[ -n "$layout" ] || exit 1

if [ -f "$dir/hyprland.lua" ]; then
    q() { printf '"%s"' "$(printf %s "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
    body="input = { kb_layout = $(q "$layout"), kb_variant = $(q "$variant"), kb_options = $(q "$options") },"
    hyprctl eval "hl.config({ $body })" >/dev/null
    mkdir -p "$dir/config"
    {
        echo "-- Written by the quickshell Settings (Keyboard page); changes made here are overwritten."
        echo "hl.config({"
        echo "    input = {"
        echo "        kb_layout  = $(q "$layout"),"
        echo "        kb_variant = $(q "$variant"),"
        echo "        kb_options = $(q "$options"),"
        echo "    },"
        echo "})"
    } > "$dir/config/keyboard.lua"
    hyprctl switchxkblayout all 0 >/dev/null
    exit 0
fi

# right now, for every keyboard
hyprctl keyword input:kb_layout "$layout" >/dev/null
hyprctl keyword input:kb_variant "$variant" >/dev/null
hyprctl keyword input:kb_options "$options" >/dev/null

# and from now on
mkdir -p "$dir/config"
{
    echo "# Written by the quickshell Settings (Keyboard page); changes made here are overwritten."
    echo "input {"
    echo "    kb_layout = $layout"
    echo "    kb_variant = $variant"
    echo "    kb_options = $options"
    echo "}"
} > "$conf"

if [ -f "$main" ] && ! grep -qF 'config/keyboard.conf' "$main"; then
    if grep -qF 'config/windowrules.conf' "$main"; then
        sed -i '/config\/windowrules.conf/a source = ~/.config/hypr/config/keyboard.conf' "$main"
    else
        echo 'source = ~/.config/hypr/config/keyboard.conf' >> "$main"
    fi
fi

# start on the first layout
hyprctl switchxkblayout all 0 >/dev/null
