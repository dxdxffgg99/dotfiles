-- =============================================
-- ENV
-- =============================================
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XCURSOR_SIZE", 24)
hl.env("HYPRCURSOR_SIZE", 24)
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", 1)

hl.monitor({
    output   = "eDP-1",
    mode     = "2880x1920@120",
    position = "0x0",
    scale    = 1.67,
})

local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "rofi"
local browser     = "google-chrome-stable"

hl.config({
    general = {
        gaps_in          = 5,
        gaps_out         = 20,
        border_size      = 2,
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
        col = {
            active_border   = { colors = { "rgba(a8d8ffee)", "rgba(baffc9ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
    },
    decoration = {
        rounding         = 10,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.75,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },
        blur = {
            enabled  = true,
            size     = 4,
            passes   = 1,
            vibrancy = 0.5,
            xray     = false,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = true,
        always_follow_on_dnd = true,
        animate_manual_resizes = false,
    },
    xwayland = {
        force_zero_scaling = true,
    },
    cursor = {
        no_hardware_cursors = false,
    },
})

hl.config({
    plugin = {
        hyprgrass = {
            sensitivity = 1.0,
            long_press_delay = 400,
        },
        hyprglass = {
            default_theme = "dark",
            default_preset = "clear",
            tint_color = 0x8899aa22,
            brightness = 0.75,
            layers = {
                enabled = 1,
                namespaces = "kitty",
                preset = "clear",
            },
            dark = { brightness = 0.82 },
            light = { adaptive_boost = 0.5 },
        },
    },
})

-- 3-finger horizontal swipe to switch workspaces
hl.plugin.hyprgrass.gesture({
    pattern = { kind = "swipe", fingers = 3, direction = "horizontal" },
    action = "workspace",
})

-- swipe up from the bottom edge to open the gloview overview
hl.plugin.hyprgrass.bind({
    pattern = { kind = "edge", origin = "d", direction = "u" },
    action = hl.plugin.gloview.toggle,
})

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + TAB", hl.plugin.gloview.toggle)

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,   hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize())

hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd("vesktop --enable-features=VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE"))
hl.bind(mainMod .. " + ALT + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + SPACE",   hl.dsp.exec_cmd("ls ~/.local/bin | rofi -dmenu | xargs -I {} setsid -f ~/.local/bin/{}"))
hl.bind(mainMod .. " + insert",  hl.dsp.exec_cmd("grim -g \"$(slurp)\" -t png - | wl-copy -t image/png"))
hl.bind(mainMod .. " + L",       hl.dsp.exec_cmd("BRV=$(brightnessctl get) && brightnessctl set 25% && hyprlock && brightnessctl set $BRV"))

local volumeNotifyCmd = "VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%d\", $2*100}') && notify-send -r 91190 -h int:value:\"$VOL\" -t 1500 \"Volume: ${VOL}%\""
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && " .. volumeNotifyCmd), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && " .. volumeNotifyCmd),      { locked = true, repeating = true })

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("fcitx5")
    hl.exec_cmd("wvkbd-mobintl --hidden -H 400 -L 300")
    hl.exec_cmd("waybar")
    hl.exec_cmd("awww-daemon & for _ in $(seq 50); do awww query >/dev/null 2>&1 && break; sleep 0.1; done; awww img ~/.config/wp.png")
    hl.exec_cmd(terminal)
end)
