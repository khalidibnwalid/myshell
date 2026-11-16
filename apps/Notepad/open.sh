#!/bin/sh
# What the desktop entry runs: open Notepad, with a file when the system hands one over.
# usage: open.sh [FILE]
if [ -n "$1" ]; then
    exec qs ipc call notepad openFile "$1"
fi
exec qs ipc call notepad open
