#!/bin/sh
# Opens a file in Paint when one is given, else just the window.
if [ -n "$1" ]; then
    exec qs ipc call paint openFile "$1"
fi
exec qs ipc call paint open
