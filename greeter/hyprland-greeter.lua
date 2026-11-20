-- Minimal Hyprland used only to host the greeter (Hyprland 0.55+ reads Lua configs)
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = 0xff0f1417,
    },
    animations = { enabled = false },
})

hl.on("hyprland.start", function()
    -- when the greeter exits (after a successful login) so does this compositor
    hl.exec_cmd("qs -p /etc/greetd/quickshell-greeter; hyprctl dispatch exit")
end)
