#!/bin/sh
# Builds audio-mpris into the given folder (default: the user's cache) and prints its path.
# Needs Go; the one dependency (godbus) is fetched on the first build. Does nothing when the binary is
# newer than the sources.
set -e
src=$(cd "$(dirname "$0")" && pwd)
out=${1:-${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/audio}
bin="$out/audio-mpris"
mkdir -p "$out"

if [ -x "$bin" ] && [ "$bin" -nt "$src/main.go" ] && [ "$bin" -nt "$src/go.mod" ] && [ "$bin" -nt "$src/build.sh" ]; then
    echo "$bin"
    exit 0
fi

cd "$src"
go build -trimpath -ldflags "-s -w" -o "$bin.tmp" . >&2
mv "$bin.tmp" "$bin"
echo "$bin"
