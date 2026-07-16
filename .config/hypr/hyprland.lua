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

-- =============================================
-- MONITOR
-- =============================================
hl.monitor({
    output   = "eDP-1",
    mode     = "2880x1920@120",
    position = "0x0",
    scale    = 1.67,
})

-- =============================================
-- VARIABLES
-- =============================================
local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "rofi"
local browser     = "google-chrome-stable"

-- =============================================
-- CONFIG
-- =============================================

hl.config({
    general = {
        gaps_in          = 5,
        gaps_out         = 20,
        border_size      = 2,
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
    },
    decoration = {
        rounding         = 10,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.9,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },
        blur = {
            enabled  = true,
            size     = 4,
            passes   = 2,
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
    },
    xwayland = {
        force_zero_scaling = true,
    },
    cursor = {
        no_hardware_cursors = true,
    },
})

-- =============================================
-- KEYBINDS
-- =============================================
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,   hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + 0",         hl.dsp.focus({ workspace = 10 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize())

hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd("vesktop"))
hl.bind(mainMod .. " + ALT + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("~/.appdata/lmstudio.AppImage"))
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("~/.appdata/obsidian.AppImage"))
hl.bind(mainMod .. " + SPACE",   hl.dsp.exec_cmd("ls ~/.local/bin | rofi -dmenu | xargs -I {} setsid -f ~/.local/bin/{}"))
hl.bind(mainMod .. " + insert",  hl.dsp.exec_cmd("grim -g \"$(slurp)\" -t png - | wl-copy -t image/png"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl set 5%+"),                          { locked = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl set 5%-"),                          { locked = true })

-- =============================================
-- AUTOSTART
-- =============================================
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("fcitx5")
    hl.exec_cmd("waybar")
    hl.exec_cmd("[ -f ~/.config/wp.png ] || curl -fsSL https://raw.githubusercontent.com/dxdxffgg99/dotfiles/main/.config/wp.png -o ~/.config/wp.png && (awww-daemon && awww img ~/.config/wp.png")
    hl.exec_cmd(terminal)
end)
