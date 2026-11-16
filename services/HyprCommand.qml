pragma Singleton

import Quickshell

// Hyprland commands: go to a workspace, focus or move a window.
// Hyprland 0.57 takes them as Lua (`hl.dsp.focus({ workspace = 2 })`) and no longer reads the
// old `workspace 2` form; older versions only know the old form. So each command is sent as Lua
// first and, if Hyprland does not answer "ok", in the old form.
Singleton {
    id: root

    function run(lua, classic) {
        Quickshell.execDetached(["sh", "-c", "case \"$(hyprctl dispatch \"$1\" 2>&1)\" in ok*) ;; *) hyprctl dispatch \"$2\" >/dev/null 2>&1 ;; esac", "sh", lua, classic]);
    }

    // a window id is Hyprland's "0x..." address; anything else is dropped, so it cannot break the text
    function clean(text) {
        return String(text).replace(/[^0-9a-zA-Z_:.^$()|\-]/g, "");
    }

    function goToWorkspace(id) {
        const n = parseInt(id);
        if (!isNaN(n))
            run("hl.dsp.focus({ workspace = " + n + " })", "workspace " + n);
    }

    function focusWindow(address) {
        const a = clean(address);
        run("hl.dsp.focus({ window = \"address:" + a + "\" })", "focuswindow address:" + a);
    }

    function focusClass(cls) {
        const c = clean(cls);
        run("hl.dsp.focus({ window = \"class:^(" + c + ")$\" })", "focuswindow class:^(" + c + ")$");
    }

    function moveWindowToWorkspace(address, id) {
        const a = clean(address);
        const n = parseInt(id);
        if (!isNaN(n))
            run("hl.dsp.window.move({ workspace = " + n + ", follow = false, window = \"address:" + a + "\" })", "movetoworkspacesilent " + n + ",address:" + a);
    }
}
