#!/bin/sh
# Applies keyboard layouts to Hyprland and keeps them across restarts.
# usage: apply-keyboard.sh LAYOUTS VARIANTS OPTIONS HYPR_DIR
#   e.g. apply-keyboard.sh us,ara "" grp:alt_shift_toggle ~/.config/hypr
# The layouts are written to HYPR_DIR/config/keyboard.conf, which hyprland.conf sources
# (the line is added once if it is missing).
layout=$1
variant=$2
options=$3
dir=$4
conf="$dir/config/keyboard.conf"
main="$dir/hyprland.conf"

[ -n "$layout" ] || exit 1

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
