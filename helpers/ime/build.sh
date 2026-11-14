#!/bin/sh
# Builds qs-ime into the given folder (default: the user's cache) and prints its path.
# Needs a C compiler, wayland-scanner and the wayland-client, xkbcommon and pango headers. Does nothing when the
# binary is newer than the sources.
set -e
src=$(cd "$(dirname "$0")" && pwd)
out=${1:-${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/ime}
bin="$out/qs-ime"
mkdir -p "$out"

if [ -x "$bin" ] && [ "$bin" -nt "$src/qs-ime.c" ] && [ "$bin" -nt "$src/build.sh" ]; then
    echo "$bin"
    exit 0
fi

for proto in input-method-unstable-v2 virtual-keyboard-unstable-v1; do
    wayland-scanner client-header "$src/protocol/$proto.xml" "$out/$proto-client-protocol.h"
    wayland-scanner private-code "$src/protocol/$proto.xml" "$out/$proto-protocol.c"
done

${CC:-cc} -O2 -Wall -Wno-unused-parameter -I"$out" -o "$bin.tmp" \
    "$src/qs-ime.c" "$out/input-method-unstable-v2-protocol.c" "$out/virtual-keyboard-unstable-v1-protocol.c" \
    $(pkg-config --cflags --libs wayland-client xkbcommon pangocairo)
mv "$bin.tmp" "$bin"
echo "$bin"
