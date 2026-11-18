#!/bin/sh
# Talks to the Audio program (audio.qml), and starts it first when the command needs it.
# usage: ctl.sh COMMAND [ARG]...
#   open | toggle | close | playpause | play | pause | stop | next | previous
#   openFile FILE | enqueue FILE | volume 0-100 | status | quit
dir=$(cd "$(dirname "$0")/../../.." && pwd)
cfg="$dir/audio.qml"

if ! qs -p "$cfg" ipc call audio status >/dev/null 2>&1; then
    # not running: only a command that wants sound or a window starts it
    case $1 in
        open | toggle | playpause | play | openFile | enqueue) ;;
        *) exit 0 ;;
    esac
    setsid -f qs -p "$cfg" >/dev/null 2>&1
    tries=0
    until qs -p "$cfg" ipc call audio status >/dev/null 2>&1; do
        tries=$((tries + 1))
        [ "$tries" -gt 50 ] && exit 1
        sleep 0.2
    done
fi
exec qs -p "$cfg" ipc call audio "$@"
