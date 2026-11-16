---
name: quickshell-add-app
description: Step by step recipe for adding a small app of its own to this Quickshell config (like Notepad): a folder under apps/ with the window, its service, icon and launch script, IPC and shortcut, launcher result, dock tile, desktop entry (also as a default app for file types), window rule and README. Use when the user asks for a new app, tool window or utility built into the shell.
---

# Adding an app (Notepad is the model)

**Apps live in `apps/<App>/`, not in `modules/` or `services/`.** Those folders are for the shell itself (bar, panels, system services). One app = one folder holding everything of its own:

```
apps/Notepad/Notepad.qml   the window
apps/Notepad/Notes.qml     its service (singleton, found by bare name: same folder)
apps/Notepad/notepad.svg   its icon
apps/Notepad/open.sh       what the desktop entry runs
```

Shared things stay where they are: `components/`, `config/`, and `services/WindowManager.qml` (the `<app>Visible` flag). Inside `apps/<App>/` the imports are the same as in `modules/<Area>/` (`../../components`, `../../config`, `../../services/`). `shell.qml` imports `"apps/<App>"`. The install script and the launcher result point at `apps/<App>/<app>.svg`.

1. **Name things apart.** The window type and the service singleton must not share a name. Window `Notepad`, service `Notes`.
2. **Service** (`apps/<App>/<Thing>.qml`, singleton): holds the data and every change to it. Store under `$XDG_DATA_HOME/quickshell/<app>/` (small JSON file), not in the config folder.
   - Load with `Process` (`mkdir -p` then `cat`) and write with `FileView { preload: false; atomicWrites: true }`.
   - **Never write before the load finished** (`if (!loaded) return` in `save()`), and queue an action asked for before that (`createPending`, `openPending`). Otherwise a fast IPC call overwrites the saved data.
   - A file that fails to parse is copied to `<file>.corrupt`, never written over.
   - Edits in place (`obj.text = ...`) do not change a `property var`: call `xChanged()` and make bindings that read the object depend on the list (`Notes.notes;` as the first statement of the binding), or they stay stale.
   - Save typing with a restart `Timer` (about 600 ms), other actions at once.
   - **Files the user opens or saves**: the item remembers its `path`. Read with `Process` (`head -c` limit, path as an argument, never inside the shell string). Write by **stdin** (`stdinEnabled: true`, `onStarted: { write(text); stdinEnabled = false; }`), because a long text does not fit in one argument. Report with a short `status` that a `Timer` clears. File pickers are `QtQuick.Dialogs` `FileDialog` (open, and `FileDialog.SaveFile`); Ctrl+S saves to the remembered path or asks, Ctrl+Shift+S always asks, Ctrl+O opens.
3. **Window**: an `ApplicationWindow` with `visible: WindowManager.<app>Visible`, `onClosing` clears it, same `color:` expression as `Settings.qml` (`Config.appearance.settingsOpacity`), `title: "<App>"`. Add `property bool <app>Visible` and an `open<App>()` function to `WindowManager`; if opening an already open window should raise it, add a `<app>RaiseRequested` signal and call `raise(); requestActivate()` from it.
   - Build it from existing components (`ListRow`, `IconButton`, `FieldInput`, `StyledText`, `Appearance.*`); see `quickshell-components`.
   - **Title bar**: the app's actions (open, save, copy, pin, delete…) are `IconButton`s in a header row at the top right, ending with the close button (`close` symbol) that clears `<app>Visible`. The footer only carries information (counts, status). Show the way back to a folded panel there too, as a visible button, not only a shortcut.
   - **Side list**: an `Item` that clips and animates `Layout.preferredWidth` (min/max bound to it; `Behavior` off while dragging) around a column of the dragged width. A `MouseArea` on its right edge resizes it (clamp 180-480); dragging below about 120 folds it away. Keep an even 12 px margin on every side, also when the panel is folded.
   - **Markdown**: a `View`/`Edit` `Segmented` in the title bar (and a shortcut). View is a `Text { textFormat: Text.MarkdownText }` in a `ScrollView` (`contentWidth: availableWidth`); it renders headings, lists, task boxes, tables, quotes, code and links. `Text.linkColor` has no effect on Markdown here (links stay dark blue). Do not use a read-only `TextArea` for the view: it swallowed the toggle shortcut. A focused `TextArea` also keeps `Ctrl+E` (end of line); use `Ctrl+Shift+V` for the mode switch.
   - **A note created with content** (opened from a file) must be built with that content (`create(text, path)`), not filled in afterwards: the editor loads when the note is selected and never notices later in-place changes (it also reloads on `notesChanged()` while unfocused).
   - A list the user can reorder: keep the order in the stored array itself (new items prepended), show rows by slot in a `Flickable` (`y: slot * (rowHeight + gap)`, `interactive: !dragging`) and drag them with a `DragHandler { target: null; xAxis.enabled: false }` on the row, which keeps the row's own click working. While dragging only a `list.order` array changes; save it once when the drag ends. Switch dragging off while a search filters the list. `components/SortableList` is for plain rows without click, selection or an `x`.
   - A list row that can be removed shows an `x` (`IconButton` over the row, `visible: row.hovered || x.hovered`, `trailingSpace` so the title keeps clear of it).
4. **Start it** in `shell.qml`: import `apps/<App>` and add `<App> {}`. A service is created lazily, so call `refresh()` from the window when it opens.
5. **Ways to open it**: an `IpcHandler` (`target: "<app>"`, functions `toggle`, `open`, `close`, plus `openFile(path: string)` when it opens files; never `show`), a `GlobalShortcut { name: "<app>" }` (the user binds `global, quickshell:<app>`), and in-window `Shortcut`s. Opening over IPC does not give the window keyboard focus on this machine; do not call it a bug.
6. **Launcher**: in `services/Search.qml`, next to the Settings entry, push an `own` result (`type: "app"`, `image: Quickshell.shellDir + "/apps/<App>/<app>.svg"` (the dock's icon), `symbol` and `icon` = a Material symbol as fallback, `execute: () => WindowManager.open<App>()`) for the words that should find it; `own` entries replace a desktop-entry result of the same name.
7. **Dock, icon, default app**: the shell's windows share one app id (`dev.noctalia.noctalia-qs`), so the dock cannot tell them apart.
   - Add `apps/<App>/<app>.svg` (128 viewBox, `#1b2125` rounded tile, `#92cef5` shape, like `assets/settings.svg`) and `apps/<App>/open.sh` (runs `qs ipc call <app> openFile "$1"` when given a file, else `open`).
   - Extend `scripts/install-app-icons.sh` (the shell runs it at start) to install the icon and a **visible** `quickshell-<app>.desktop`: `Exec="$dir/apps/<App>/open.sh" %f`, `Icon=quickshell-<app>`, and `MimeType=` for the types it can open. When the entry changes the script runs `update-desktop-database`, which makes the app appear in Settings → Default apps (that page reads `gio mime <type>`); the user picks it there, nothing is set for them.
   - In `DockApps.windowId()` map the window title to `quickshell-<app>`. The running shell sees a new icon only after a restart (`qs kill; setsid -f qs`).
8. **Window rule** (the user's `~/.config/hypr/config/windowrules.lua`, the one place besides the one `source` line we touch, and only because they asked): copy the Settings line with the new title (`float`, `size`, `center`), then `hyprctl reload`.
9. **README**: add a short section (what it is, where the data lives, IPC, bind line, shortcuts, the window rule, the file types it can open). Add any new command-line tool to the dependency list and `AboutPage.qml`'s `tools` map.
10. **Verify** (see `quickshell-verify`): reload log clean; `qs ipc call <app> open`; `hyprctl clients -j` shows the window floating at the rule's size; check the data file by content; `gio mime text/plain` lists the app; run `open.sh /some/file` and look at the result. Hot reloads (any file saved under the config folder, `.claude/` too) can leave a test window showing a stale frame; restart the shell (`qs kill; setsid -f qs`) before judging a screenshot. Typing tests: focus the window with `hyprctl dispatch "hl.dsp.focus({ window = \"address:0x...\" })"` (this Hyprland uses Lua dispatch syntax), confirm `hyprctl activewindow` is the app **before** every `wtype`, or the keys land in the user's terminal. Remove test data and debug hooks (`grep -c "TEMP debug"`), then report what was seen and what was not, and ask whether to commit.
