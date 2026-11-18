#!/bin/sh
# What the desktop entry runs: open Audio, and play the files the system hands over.
# usage: open.sh [FILE]...
ctl="$(dirname "$0")/scripts/ctl.sh"
if [ -z "$1" ]; then
    exec "$ctl" open
fi
"$ctl" openFile "$1"
shift
for f in "$@"; do
    "$ctl" enqueue "$f"
done
