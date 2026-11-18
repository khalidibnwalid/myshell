#!/bin/sh
# Builds paint-engine into the given folder (default: the user's cache) and prints its path.
# Needs Go; it has no dependencies. Does nothing when the binary is newer than the sources.
set -e
src=$(cd "$(dirname "$0")" && pwd)
out=${1:-${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/paint}
bin="$out/paint-engine"
mkdir -p "$out"

newest=$(ls -t "$src"/*.go "$src"/go.mod "$src"/build.sh | head -n 1)
if [ -x "$bin" ] && [ "$bin" -nt "$newest" ]; then
    echo "$bin"
    exit 0
fi

cd "$src"
go build -trimpath -ldflags "-s -w" -o "$bin.tmp" . >&2
mv "$bin.tmp" "$bin"
echo "$bin"
