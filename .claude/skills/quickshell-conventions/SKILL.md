---
name: quickshell-conventions
description: How code in this Quickshell config is structured and what to avoid. Use before writing or changing any QML, service, config key, shell command, IPC handler or commit in this repo.
---

# Quickshell config: code conventions

## Layout
- `shell.qml` starts the modules and apps. `modules/<Area>/` hold windows and pages of the shell, `apps/<App>/` hold small apps of their own (window, service, icon, launch script together; see `quickshell-add-app`), `components/` the reusable QML, `services/` the singletons that read or change the system, `config/` the config singleton and theme (`Appearance`), `scripts/` only for things that cannot be inline, `helpers/` compiled helpers, `assets/` images shipped with the repo.
- A singleton that nothing references at startup is created lazily. If it must work without its page being open (borders, keyboard light idle, launcher index), call `Services.X.refresh()` from `shell.qml`'s `Component.onCompleted`.

## Services
- `pragma Singleton`, `Singleton { id: root }`. Expose `property`/`readonly property`, small functions, and signals. Read with `Process` + `StdioCollector`; poll with a `Timer` only while something needs it (pages poll while open).
- Never paste user text into a shell string. Pass it as arguments: `["sh", "-c", "script using $1 $2", "sh", arg1, arg2]`. Build `find`/`gio`/`busctl` commands the same way.
- Closures that outlive the `Process` that made them lose their context (`root is not defined`). Build result rows in a function of the singleton, not inside the Process's `onStreamFinished`.
- Prefer one inline `sh` command in QML over a new script file when it is a short pipeline (the user prefers this; scripts only for compiled/long logic or when a file is shared by several callers). Shared shell fragments live in a service (see `FilePreview`).

## Memory and weight (measured, 2026-11-18)
- Measure with **PSS**, not RSS: `awk '/^Pss:/{print $2/1024}' /proc/<pid>/smaps_rollup` (MB). RSS (`ps`, btop, the old Processes page) counts the shared libraries (Qt, Mesa, NVIDIA, FFmpeg, ~170 MB per Quickshell process) in full. A bare `qs` with no window is ~69 MB PSS, a window ~80, the Audio program with its window closed and a track playing ~81 plus mpv ~49.
- **Do not build a window that is not shown.** A hidden `ApplicationWindow` still instantiates every view and binding. A program app keeps only a small always-on `Scope` (`<App>Program.qml`: IPC, loading, quit timer) and creates the window with a `LazyLoader { active: shown; component: <App> {} }`; closing sets `shown = false` and the window is destroyed (`apps/Audio/AudioProgram.qml`). The window gets `program` and sets `program.shown = false` to close. Create heavy children (file dialogs) on first use with a `Loader`.
- **Engines run out of process.** Qt Multimedia cost ~80 MB while playing; Audio plays through `mpv` (`apps/Audio/MpvEngine.qml`, a windowless mpv driven over `--input-ipc-server` with a `Socket`, volume as `volume-gain` in dB, started on first play, killed with the shell by `setpriv --pdeathsig KILL`). Prefer a small external process over a heavy Qt module.
- **Helpers are small Go programs** (`helpers/audio-mpris`: godbus, ~5 MB instead of a 34 MB Python + gobject). Pattern: `helpers/<name>/{main.go,go.mod,go.sum,build.sh}`; `build.sh OUTDIR` builds into the cache only when the sources are newer and prints the binary path; QML runs `["sh","-c",'b=$("$1/helpers/<name>/build.sh" "$2") && exec "$b"',"sh",Quickshell.shellDir,cacheDir]`. The user chose Go over Rust for helpers (easy to recompile, same performance here). Add `go` (and the tool) to README and `AboutPage` tools.
- Tuning that did **not** help: `MALLOC_ARENA_MAX` / `MALLOC_TRIM_THRESHOLD_` (no change), the software renderer (~15-20 MB only), removing views from a hidden window. Cover images were already small (`sourceSize` at 2x, covers scaled to 480 px): check the data before blaming images.
- Show memory as PSS in UI (Processes page: PSS every 6 s from `smaps_rollup` via `grep -H`, since `awk` aborts on the first unreadable file; RSS fallback for other users' processes).

## Helpers that speak a system protocol (D-Bus backends, portals)
- Go + godbus under `helpers/<name>/` with `build.sh` (see above); the shell starts it with `Process { stdinEnabled: true; stdout: SplitParser }` and talks JSON lines (one object per line, `id` to match answers). Restart it a few times if it exits, then leave it off (the system's own backend keeps working).
- The helper exposes `install` / `uninstall` subcommands for the small files it needs (`*.portal`, `*-portals.conf`, a D-Bus `.service`) and prints `changed` only when it wrote or removed something; the shell restarts the system service (`xdg-desktop-portal`) only then. It never overwrites a file it did not write (a marker comment line tells), and it explains what to add by hand instead.
- Always give a fallback for when the shell is not running (a `--fallback` instance started by D-Bus activation that forwards to the stock backend, replaced by the shell's own instance with `AllowReplacement` / `ReplaceExisting`).
- Gate it behind `<section>.enabled`, loaded by an always-present scope that reacts to the value (`onActiveChanged`), not by `Component.onDestruction`.

## Desktop entries
- `Exec=` has its path **unquoted** unless it contains a space or a special character. `xdg-open` (generic DE) looks the first word up with its quotes still on; a quoted path is "not found" and it falls back to `$BROWSER` (picking an audio file in the launcher opened Firefox). `scripts/install-apps.py` (`exec_word`) and `scripts/install-app-icons.sh` (Notepad) do it. `install-apps.py` also removes entries of apps that no longer exist (an entry whose launcher file is missing), never ones another script made (Notepad has no `app.json`).
- Test an entry with `xdg-open <file>` (not only `xdg-mime query default`) and `sh -x /usr/bin/xdg-open` to see where it falls through.

## Config
- `config.json` is the hand-written base. Settings changes go to `config.overrides.json` (generated, git-ignored). Never write settings into `config.json` from code.
- Add a key in three places: default in `config/Config.qml`, `config.schema.json`, and (if it needs a non-default base) `config.json`.
- Sections in `objectSections` are `JsonObject`s (assign `Config.x.key = v`). Sections in `plainSections` (`keyboard`, `hyprland`, `search`, `clipboard`) are plain objects: replace the whole value with `Config.setIn("search", "key", value)`. Read optional keys as `Config.search?.key ?? default` so a missing key means the default.
- A defaults rule: the default of a new setting is what the user's current setup already does.

## Hyprland
- Options come from `hyprctl descriptions -j` (types, ranges, choices); live values from `hyprctl getoption`. Never trust the `current` field of descriptions.
- Our output goes only to `~/.config/hypr/config/quickshell.conf` and `quickshell.lua`, included last. The user's own hypr files are never edited except the one `source`/`dofile` line added by `scripts/apply-*.sh`.
- Apply live with `hyprctl --batch "keyword a v ; keyword b w"`; a reset or removal needs `hyprctl reload`.

## The bar
- `Config.barSize` (50) is the room the bar takes: the distance from the screen edge to the first window (the layer's exclusive zone). Every bar style (`Appearance.barStyle`: classic, capsule, islands, inset) keeps gap + shape equal to it (`Appearance.barEdgeMargin` is 4 on the floating styles and `barInnerMargin` is 0, so the shape is 46 wide and grows toward the windows; centre content on the shape with the shift in `Bar.qml`). Never change the window size to restyle the bar; verify with `hyprctl monitors -j` (`reserved`) and `hyprctl layers -j` after any bar change.
- The Inset style's rounded screen corners are two small non-reserving, click-through layer windows per screen (`modules/Bar/BarCorner.qml`). A `Variants` delegate must be a window or `Scope`; a `Repeater` cannot create windows.

## QML engine limits here (old JS engine)
- No `Array.prototype.flatMap`, no `String.matchAll` (use a loop with `regex.exec`), no `Qt.fontFamilies()` per delegate (cache it).
- `property color color` clashes on a `Rectangle`; use another name (`fillColor`). Avoid a property called `state` on an Item/Singleton (use `byCategory`).
- Two `Component.onCompleted` handlers in one object is an error: merge them.
- `Audio` is a component to instantiate (`Audio { id: audio }`), not a singleton.
- In services imported with a prefix (`import "../../services/" as Services`) use `Services.WindowManager`; a bare name is a runtime ReferenceError.
- Name IPC functions anything except `show` (it collides with `qs ipc show`).

## Git
- Commit straight to `master`. Message: `feat(scope): title` or `fix: title`, then short bullet lines. No `Co-Authored-By` trailer (the user said so twice; strip one that slipped in). Group commits by feature; amend or squash into the feature commit when asked.
- Before amending, squashing or rewriting, run `git status -sb`: only commits that show as `ahead N` and are not pushed may be rewritten. Remove a backup ref that `filter-branch` leaves (`git update-ref -d refs/original/refs/heads/master`).
- If git has no identity (`Author identity unknown`), commit with `git -c user.name=... -c user.email=...` using the author of the repo's history, once; never write git config.
- Stage what belongs to the change by path; the working tree may hold another session's edits.
- `.claude/`, `TODO.md`, `config.overrides.json`, `usage_stats.json` are local files.
- Keep `README.md` dependencies and `AboutPage.qml`'s `tools` map in step with any new command-line tool.
