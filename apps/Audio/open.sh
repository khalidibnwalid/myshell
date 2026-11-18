#!/bin/sh
# What the desktop entry runs: open Audio, and play the files the system hands over.
# usage: open.sh [FILE]...
if [ -z "$1" ]; then
    exec qs ipc call audio open
fi
qs ipc call audio openFile "$1"
shift
for f in "$@"; do
    qs ipc call audio enqueue "$f"
done
