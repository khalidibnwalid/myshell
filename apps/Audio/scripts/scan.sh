#!/bin/sh
# Indexes the audio folders. Every file gets a small record in CACHE/idx (tags, length, cover), made
# once and redone only when the file changes; the records of the files found now are printed.
# usage: scan.sh CACHE DIR_OR_FILE...        print the records
#        scan.sh --probe CACHE FILE          (used by the line above)
export LC_ALL=C.UTF-8

if [ "$1" = "--probe" ]; then
    cache=$2
    f=$3
    key=$(printf '%s' "$f" | md5sum | cut -d' ' -f1)
    rec="$cache/idx/$key"
    mtime=$(stat -c %Y -- "$f") || exit 0
    grep -qx "v=3" "$rec" 2>/dev/null && grep -qx "mtime=$mtime" "$rec" 2>/dev/null && exit 0

    info=$(ffprobe -v error -of flat -show_entries 'format=duration:format_tags:stream=codec_type:stream_disposition=attached_pic' -i "$f" 2>/dev/null)
    [ -n "$info" ] || exit 0

    fields=$(printf '%s\n' "$info" | awk '
        function val(s) { sub(/^[^=]*=/, "", s); gsub(/^"|"$/, "", s); gsub(/\\"/, "\"", s); gsub(/\\\\/, "\\", s); return s }
        {
            k = tolower(substr($0, 1, index($0, "=") - 1))
            if (k == "format.duration") print "duration=" val($0)
            else if (k == "format.tags.title") print "title=" val($0)
            else if (k == "format.tags.artist") print "artist=" val($0)
            else if (k == "format.tags.album") print "album=" val($0)
            else if (k == "format.tags.album_artist" || k == "format.tags.albumartist") print "albumartist=" val($0)
            else if (k == "format.tags.track") print "track=" val($0)
            else if (k == "format.tags.disc") print "disc=" val($0)
            else if (k == "format.tags.date" || k == "format.tags.year") print "date=" val($0)
            else if (k == "format.tags.genre") print "genre=" val($0)
            else if (k ~ /^streams\.stream\.[0-9]+\.codec_type$/) { if (val($0) == "video") video[k] = 1 }
            else if (k ~ /^streams\.stream\.[0-9]+\.disposition\.attached_pic$/) { if (val($0) == "1") pic[k] = 1 }
        }
        END {
            n = 0; p = 0
            for (k in video) n++
            for (k in pic) p++
            print "video=" ((n - p) > 0 ? 1 : 0)
            print "pic=" (p > 0 ? 1 : 0)
        }')
    duration=$(printf '%s\n' "$fields" | sed -n 's/^duration=//p' | head -n1)
    video=$(printf '%s\n' "$fields" | sed -n 's/^video=//p')
    pic=$(printf '%s\n' "$fields" | sed -n 's/^pic=//p')

    cover=""
    out="$cache/covers/$key.jpg"
    if [ "$pic" = 1 ]; then
        ffmpeg -v error -y -i "$f" -an -map 0:v:0 -frames:v 1 -vf "scale='min(480,iw)':-2" "$out" >/dev/null 2>&1 && cover=$out
    elif [ "$video" = 1 ]; then
        at=$(printf '%s' "${duration:-0}" | awk '{ printf "%d", $1 / 10 }')
        ffmpeg -v error -y -ss "${at:-0}" -i "$f" -an -map 0:v:0 -frames:v 1 -vf "scale='min(480,iw)':-2" "$out" >/dev/null 2>&1 && cover=$out
    fi
    if [ -z "$cover" ]; then
        dir=$(dirname -- "$f")
        for n in cover folder front album Cover Folder Front Album; do
            for e in jpg jpeg png; do
                if [ -f "$dir/$n.$e" ]; then
                    cover="$dir/$n.$e"
                    break 2
                fi
            done
        done
    fi
    [ -s "$out" ] || rm -f "$out"

    {
        echo "v=3"
        echo "path=$f"
        echo "mtime=$mtime"
        printf '%s\n' "$fields" | grep -v '^pic='
        echo "cover=$cover"
    } > "$rec.tmp" && mv "$rec.tmp" "$rec"
    exit 0
fi

cache=$1
shift
mkdir -p "$cache/idx" "$cache/covers"
list=$(mktemp)
trap 'rm -f "$list"' EXIT

for target in "$@"; do
    if [ -d "$target" ]; then
        find "$target" -type f \( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.ogg' -o -iname '*.oga' -o -iname '*.opus' -o -iname '*.m4a' -o -iname '*.aac' -o -iname '*.wav' -o -iname '*.wma' -o -iname '*.mka' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.m4b' -o -iname '*.ape' -o -iname '*.wv' \) -print0
    elif [ -f "$target" ]; then
        printf '%s\0' "$target"
    fi
done | sort -zu > "$list"

xargs -0 -a "$list" -n1 -P4 sh "$0" --probe "$cache"

xargs -0 -a "$list" -n1 sh -c '
    key=$(printf "%s" "$2" | md5sum | cut -d" " -f1)
    [ -f "$1/idx/$key" ] && { echo "@@"; cat "$1/idx/$key"; }
' sh "$cache" 2>/dev/null
