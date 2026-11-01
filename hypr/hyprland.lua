-- Hyprland: Samsung TV + Lenovo ultrawide on the RTX 3090, macOS-style keys with keyd (keyd-default.conf)

local tv     = "desc:Samsung Electric Company SAMSUNG 0x01000E00"
local lenovo = "desc:Lenovo Group Limited R45w-30 UPP040ZY"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
-- TV on the left at scale 2 (its 4K@60 sits at the HDMI 2.0 limit), the 32:9 at 165Hz to its right
hl.monitor({ output = tv,     mode = "3840x2160@60",  position = "0x0",    scale = 2 })
hl.monitor({ output = lenovo, mode = "5120x1440@165", position = "1920x0", scale = 1 })

-- Apps go through uwsm-app so each gets its own scope: an OOM kill takes one app, not the session
local terminal    = "uwsm-app -- kitty"
local fileManager = "uwsm-app -- nautilus"
local menu        = "pkill -x wofi || uwsm-app -- wofi"

-- waybar, hyprpaper and hypridle are user services; XWayland's primary is the TV, so fullscreen games get 4K
hl.on("hyprland.start", function ()
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("jmpd-xwayland-primary '" .. tv:sub(6) .. "'")
end)

-- Border colors come from the current theme (jmpd-theme writes theme.lua); the fallback keeps a fresh session starting
local ok, theme = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/theme.lua")
if not ok then
    theme = { active_border = "rgb(89b4fa)", inactive_border = "rgba(595959aa)" }
end

hl.config({
    general = {
        gaps_in          = 5,
        gaps_out         = 10,
        border_size      = 2,
        resize_on_border = true,
        col = {
            active_border   = theme.active_border,
            inactive_border = theme.inactive_border,
        },
    },
    decoration = {
        rounding = 0,
        shadow   = { enabled = false },
        blur     = { enabled = false },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        force_default_wallpaper        = 0,
        disable_hyprland_logo          = true,
        disable_splash_rendering       = true,
        middle_click_paste             = false,
        -- Steam Big Picture loses fullscreen when a game exits (steam-for-linux#8280): hand it to the next window
        exit_window_retains_fullscreen = true,
    },
    input = {
        -- US alt-intl: Right Alt stays AltGr for Spanish accents and ñ
        kb_layout  = "us",
        kb_variant = "alt-intl",
        kb_options = "lv3:ralt_switch",
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- 1 on the TV, 2 on the Lenovo, pinned: a TV link drop must not move a fullscreen game to the 32:9
hl.workspace_rule({ workspace = "1", monitor = tv,     default = true })
hl.workspace_rule({ workspace = "2", monitor = lenovo, default = true })

-- Super is the window key; keyd sends the Cmd system shortcuts as Ctrl+Super (marked "Cmd" below)
local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("uwsm-app -- brave"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("pkill -x wofi || jmpd-power-menu"))
hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd("uwsm stop"))  -- log out; uwsm stops the session's services first
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.layout("togglesplit"))

for key, dir in pairs({ H = "left", L = "right", K = "up", J = "down", left = "left", right = "right", up = "up", down = "down" }) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
end

local shots = "mkdir -p ~/Pictures/Screenshots && f=~/Pictures/Screenshots/$(date +%F_%H-%M-%S).png"
-- Area into satty, like flameshot: Enter copies and closes, Ctrl+S saves
local annotate = shots .. ' && grim -g "$(slurp)" - | satty --filename - --output-filename "$f" --copy-command wl-copy'
    .. ' --actions-on-enter save-to-clipboard,exit --early-exit copy save'
hl.bind("ALT + F4",              hl.dsp.window.close())                       -- Cmd+Q
hl.bind(mainMod .. " + Q",       hl.dsp.window.close())
hl.bind("CTRL + SUPER + space",  hl.dsp.exec_cmd(menu))                       -- Cmd+Space
hl.bind(mainMod .. " + space",   hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + space",        hl.dsp.exec_cmd("jmpd-theme bg-next"))               -- next wallpaper
hl.bind(mainMod .. " + CTRL + V",             hl.dsp.exec_cmd("pkill -x wofi || jmpd-clipboard"))  -- clipboard history
hl.bind(mainMod .. " + CTRL + SHIFT + space", hl.dsp.exec_cmd("pkill -x wofi || jmpd-theme"))      -- theme menu
hl.bind(mainMod .. " + CTRL + B",             hl.dsp.exec_cmd(terminal .. " -e bluetui"))
hl.bind(mainMod .. " + CTRL + A",             hl.dsp.exec_cmd(terminal .. " -e wiremix"))
hl.bind(mainMod .. " + CTRL + W",             hl.dsp.exec_cmd(terminal .. " -e impala"))
hl.bind(mainMod .. " + CTRL + T",             hl.dsp.exec_cmd(terminal .. " -e btop"))
hl.bind("CTRL + SUPER + Tab",    hl.dsp.window.cycle_next())                  -- Cmd+Tab
hl.bind("CTRL + SUPER + M",      hl.dsp.window.move({ workspace = "special:magic", follow = false })) -- Cmd+M
hl.bind("CTRL + SUPER + H",      hl.dsp.window.move({ workspace = "special:magic", follow = false })) -- Cmd+H
hl.bind("CTRL + SUPER + Q",      hl.dsp.exec_cmd("loginctl lock-session"))   -- Ctrl+Cmd+Q
hl.bind("CTRL + SUPER + left",   hl.dsp.focus({ workspace = "e-1" }))         -- Ctrl+Left
hl.bind("CTRL + SUPER + right",  hl.dsp.focus({ workspace = "e+1" }))         -- Ctrl+Right
hl.bind("CTRL + SUPER + 3",      hl.dsp.exec_cmd(shots .. ' && grim "$f" && wl-copy < "$f"'))                  -- Cmd+Shift+3
hl.bind("CTRL + SUPER + 4",      hl.dsp.exec_cmd(shots .. ' && grim -g "$(slurp)" "$f" && wl-copy < "$f"'))    -- Cmd+Shift+4
hl.bind("CTRL + SUPER + 5",      hl.dsp.exec_cmd(annotate))                   -- Cmd+Shift+5
hl.bind("Print",                 hl.dsp.exec_cmd(annotate))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys, with swayosd's on-screen level on the focused monitor
local osd = "swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')\" "
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(osd .. "--output-volume raise"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(osd .. "--output-volume lower"),       { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(osd .. "--output-volume mute-toggle"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(osd .. "--input-volume mute-toggle"),  { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })

-- XWayland drag-and-drop helper windows must not steal focus
hl.window_rule({
    name     = "fix-xwayland-drags",
    match    = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({ name = "screensaver", match = { class = "jmpd.screensaver" }, float = true, fullscreen = true })

-- Steam and its games hold off hypridle while fullscreen: no screensaver mid-game on a controller
hl.window_rule({ name = "steam-idle-inhibit", match = { class = "^(steam|steam_app_.*)$" }, idle_inhibit = "fullscreen" })
