#!/bin/sh
# Run from this folder:  sudo ./install.sh [username]
# Copies the wallpaper, colours and font from your quickshell config into the greeter.
# No (or an invalid) wallpaper is fine: the greeter then uses a plain background.
set -e
U="${1:-${SUDO_USER:?run with sudo}}"
H=$(getent passwd "$U" | cut -d: -f6)
[ -n "$H" ] || { echo "No such user: $U" >&2; exit 1; }
CFG="$H/.config/quickshell"
D=/etc/greetd/quickshell-greeter

# read a value from the appearance settings: the override file wins over config.json, like the shell
cfg() {
    v=$(jq -r ".appearance.$1 // empty" "$CFG/config.overrides.json" 2>/dev/null || true)
    [ -n "$v" ] || v=$(jq -r ".appearance.$1 // empty" "$CFG/config.json" 2>/dev/null || true)
    printf '%s' "$v"
}

# wallpaper: optional. Without a usable image the greeter shows a plain background in your colours.
WP=$(cfg wallpaper)
case "$WP" in "~/"*) WP="$H/${WP#\~/}";; esac
USE_WP=0
if [ -z "$WP" ]; then
    echo "No wallpaper set; using a plain background."
elif [ ! -f "$WP" ]; then
    echo "Wallpaper not found ($WP); using a plain background."
else
    case "$(file -b --mime-type "$WP")" in
        image/jpeg|image/png|image/webp) USE_WP=1; echo "Using wallpaper: $WP";;
        *) echo "Wallpaper is not a usable image ($WP); using a plain background.";;
    esac
fi

pacman -S --needed --noconfirm greetd
install -d "$D"
cp qmldir Theme.qml shell.qml "$D"/
rm -f "$D/wallpaper"
[ "$USE_WP" = 1 ] && install -m644 "$WP" "$D/wallpaper"
# theme colours and font from the config (invalid values keep the defaults in Theme.qml)
for k in bgColor fgColor accentColor accentColorLight; do
    v=$(cfg "$k")
    case "$v" in
        \#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]|\#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
            sed -i "s|\(property color $k: \)\"[^\"]*\"|\1\"$v\"|" "$D/Theme.qml";;
    esac
done
f=$(cfg fontFamily)
case "$f" in ""|*[\"\\\|\&]*) ;; *) sed -i "s|\(property string fontFamily: \)\"[^\"]*\"|\1\"$f\"|" "$D/Theme.qml";; esac
sed -i "s/__USER__/$U/" "$D/shell.qml"
install -d -o greeter -g greeter /var/cache/quickshell-greeter
rm -f /etc/greetd/hyprland-greeter.conf
install -m644 hyprland-greeter.lua /etc/greetd/hyprland-greeter.lua
cat > /etc/greetd/config.toml <<EOT
[terminal]
vt = 1

[default_session]
command = "systemd-cat -t greeter-hyprland start-hyprland -- -c /etc/greetd/hyprland-greeter.lua"
user = "greeter"
EOT
chown -R greeter:greeter "$D" 2>/dev/null || true
echo "Installed. Enable with: sudo systemctl enable greetd"
