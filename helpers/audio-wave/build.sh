#!/bin/sh
# Builds audio-wave into the given folder (default: the user's cache) and prints its path.
# Needs Go; there are no dependencies. Does nothing when the binary is newer than the sources.
set -e
src=$(cd "$(dirname "$0")" && pwd)
out=${1:-${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/audio}
bin="$out/audio-wave"
mkdir -p "$out"

if [ -x "$bin" ] && [ "$bin" -nt "$src/main.go" ] && [ "$bin" -nt "$src/go.mod" ] && [ "$bin" -nt "$src/build.sh" ]; then
    echo "$bin"
    exit 0
fi

cd "$src"
go build -trimpath -ldflags "-s -w" -o "$bin.tmp" . >&2
mv "$bin.tmp" "$bin"
echo "$bin"
