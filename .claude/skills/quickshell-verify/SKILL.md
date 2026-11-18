---
name: quickshell-verify
description: How to check a change to this Quickshell config actually works: reload, log, IPC, temporary debug hooks, screenshots and the known traps. Use after every edit to QML, services or shell commands in this repo.
---

# Verifying changes

The shell hot-reloads when a file under the config folder changes (about 5 seconds). The process itself keeps running.

## Quick checks
- Load: `sleep 6; qs log | grep -E "ERROR|Configuration Loaded" | tail`. The log is cumulative history, so old errors stay. Compare the count of `TypeError|ReferenceError` before and after opening the page, or look for "Configuration Loaded" after the last ERROR.
- Open a page: `qs ipc call settings page <key>` (and `settings close`). Pages run their bindings only when open, so open each page you touched.
- To exercise a page in a state it is not in (Detailed view, an inner page), temporarily flip its default property, open it, check the log, flip it back.
- Pixels: `grim -g "x,y WxH" out.png`, then read the image. The Hyprland scale on this laptop is 1.6; window geometry from `hyprctl clients -j`. Ask before taking screenshots if the user has declined one; say plainly when something was not seen on screen.

## Temporary debug hooks
Add an `IpcHandler { target: "dbg"; function dump(): string {...} }` (not named `show`) or `console.log("DBG ...")`, test, then **remove it** and `grep -c "TEMP debug" file` to confirm. Keep a backup copy of the file in the scratchpad before editing and restore it after.
Example: a search hook that calls `Search.performSearch(q)` and logs `searchFinished`, to read the rows that the launcher would show.

## Test shell commands directly
Run the exact command on this machine first (`hyprctl descriptions -j`, `gio info`, `busctl --user --json=short call ...`, `lsblk -J`). For long `sh -c` strings built in QML, test the logic with the same arguments in a terminal, or through a debug hook so the QML escaping is included.

## Known traps
- Brand-new icon files are invisible to a running Qt process (icon cache); `gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor` and restart the shell (`qs kill; setsid -f qs`) to see them.
- A change that hides something may also hide its test: pages for absent hardware do not exist in the sidebar, but `qs ipc call settings page <key>` still opens them.
- `Config` writes `config.overrides.json` on change. After a test that changed settings, remove the test keys from that file (python json edit) and `touch shell.qml` to reload; do not leave test values behind.
- `rm` inside `sh -c` may be blocked by the safety check; do not work around it, avoid the removal or leave it to the user.
- Hyprland live changes made by tests (`hyprctl keyword`) revert with `hyprctl reload` or the page's reset.

## Memory, processes and keys
- Memory: compare **PSS** (`/proc/<pid>/smaps_rollup`, MB) before and after, in the same state (window open or closed, playing or idle), several runs: one run can be 100 MB off. `Pss_Anon` is the private heap. A bare `qs -p <empty shell.qml>` (no window ~69 MB, one `ApplicationWindow` ~79 MB) is the floor to compare with. Bisect a heavy window by deleting parts of a temporary copy of the file (keep the original in the scratchpad), not by guessing.
- A second Quickshell program (`qs -p audio.qml`) has its own log: `qs -p audio.qml log`. Its processes: `pgrep -fx 'qs -p .*/audio.qml'`. Control it with `apps/Audio/scripts/ctl.sh` (`open`, `play`, `pause`, `status`, `quit`) and `playerctl -p quickshell_audio` / `busctl --user` for MPRIS.
- Keys: `wtype -k Down`, `wtype -M ctrl -k 3 -m ctrl`, typing with `-k q -k s`. Before each key focus the window and abort if `hyprctl activewindow -j` is not it (a small wrapper script in the scratchpad). Screenshot with `grim -g` from `hyprctl clients -j` geometry; the window may move between runs. A saved file hot-reloads the shell and closes open windows: reopen after edits.
- Qt Quick tests cannot run here: `qmltestrunner` and `qml` exit silently offscreen (Qt 6.12 / noctalia-qs built for 6.11). Do not spend time on it; verify through the live window and the log, and say that a click-through was not tested.

## Report
Say what was run and seen, what was only checked in the log or by data, and what is untested (e.g. a drag, a click, an action button). Then ask whether to commit or amend.
