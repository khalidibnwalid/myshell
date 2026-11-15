---
name: quickshell-conventions
description: How code in this Quickshell config is structured and what to avoid. Use before writing or changing any QML, service, config key, shell command, IPC handler or commit in this repo.
---

# Quickshell config: code conventions

## Layout
- `shell.qml` starts the modules. `modules/<Area>/` hold windows and pages, `components/` the reusable QML, `services/` the singletons that read or change the system, `config/` the config singleton and theme (`Appearance`), `scripts/` only for things that cannot be inline, `helpers/` compiled helpers, `assets/` images shipped with the repo.
- A singleton that nothing references at startup is created lazily. If it must work without its page being open (borders, keyboard light idle, launcher index), call `Services.X.refresh()` from `shell.qml`'s `Component.onCompleted`.

## Services
- `pragma Singleton`, `Singleton { id: root }`. Expose `property`/`readonly property`, small functions, and signals. Read with `Process` + `StdioCollector`; poll with a `Timer` only while something needs it (pages poll while open).
- Never paste user text into a shell string. Pass it as arguments: `["sh", "-c", "script using $1 $2", "sh", arg1, arg2]`. Build `find`/`gio`/`busctl` commands the same way.
- Closures that outlive the `Process` that made them lose their context (`root is not defined`). Build result rows in a function of the singleton, not inside the Process's `onStreamFinished`.
- Prefer one inline `sh` command in QML over a new script file when it is a short pipeline (the user prefers this; scripts only for compiled/long logic or when a file is shared by several callers). Shared shell fragments live in a service (see `FilePreview`).

## Config
- `config.json` is the hand-written base. Settings changes go to `config.overrides.json` (generated, git-ignored). Never write settings into `config.json` from code.
- Add a key in three places: default in `config/Config.qml`, `config.schema.json`, and (if it needs a non-default base) `config.json`.
- Sections in `objectSections` are `JsonObject`s (assign `Config.x.key = v`). Sections in `plainSections` (`keyboard`, `hyprland`, `search`, `clipboard`) are plain objects: replace the whole value with `Config.setIn("search", "key", value)`. Read optional keys as `Config.search?.key ?? default` so a missing key means the default.
- A defaults rule: the default of a new setting is what the user's current setup already does.

## Hyprland
- Options come from `hyprctl descriptions -j` (types, ranges, choices); live values from `hyprctl getoption`. Never trust the `current` field of descriptions.
- Our output goes only to `~/.config/hypr/config/quickshell.conf` and `quickshell.lua`, included last. The user's own hypr files are never edited except the one `source`/`dofile` line added by `scripts/apply-*.sh`.
- Apply live with `hyprctl --batch "keyword a v ; keyword b w"`; a reset or removal needs `hyprctl reload`.

## QML engine limits here (old JS engine)
- No `Array.prototype.flatMap`, no `String.matchAll` (use a loop with `regex.exec`), no `Qt.fontFamilies()` per delegate (cache it).
- `property color color` clashes on a `Rectangle`; use another name (`fillColor`). Avoid a property called `state` on an Item/Singleton (use `byCategory`).
- Two `Component.onCompleted` handlers in one object is an error: merge them.
- `Audio` is a component to instantiate (`Audio { id: audio }`), not a singleton.
- In services imported with a prefix (`import "../../services/" as Services`) use `Services.WindowManager`; a bare name is a runtime ReferenceError.
- Name IPC functions anything except `show` (it collides with `qs ipc show`).

## Git
- Commit straight to `master`. Message: `feat(scope): title` or `fix: title`, then short bullet lines. No `Co-Authored-By` trailer. Group commits by feature; amend into the feature commit when asked.
- `.claude/`, `TODO.md`, `config.overrides.json`, `usage_stats.json` are local files.
- Keep `README.md` dependencies and `AboutPage.qml`'s `tools` map in step with any new command-line tool.
