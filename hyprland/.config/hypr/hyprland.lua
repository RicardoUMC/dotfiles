-- Tokyo City Hyprland configuration (native Lua format).
-- Hyprland 0.55+ loads this file instead of the deprecated .conf format.

local terminal = "warp-terminal"
local fileManager = "wezterm start -- yazi"
local browser = "brave"
local quickshell = "env QS_DISABLE_FILE_WATCHER=1 quickshell"
local mainMod = "SUPER"

hl.monitor({ output = "DP-1", mode = "2560x1440@200", position = "1920x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "1920x1080@200", position = "0x320", scale = 1 })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", default = true })
hl.workspace_rule({ workspace = "1", monitor = "DP-2", default = true })

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 5, gaps_out = 12, border_size = 1,
        col = { active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 }, inactive_border = "rgba(595959aa)" },
        resize_on_border = false, allow_tearing = false, layout = "dwindle",
    },
    decoration = {
        rounding = 5, rounding_power = 4, active_opacity = 0.98, inactive_opacity = 0.95,
        shadow = { enabled = true, range = 4, render_power = 3, color = 0xee1a1a1a },
        blur = { enabled = true, size = 3, passes = 1, vibrancy = 0.1696 },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    master = { new_status = "master" },
    misc = { force_default_wallpaper = 2, disable_hyprland_logo = false },
    input = {
        kb_layout = "latam", kb_variant = "", kb_model = "", kb_options = "", kb_rules = "",
        follow_mouse = 1, sensitivity = 0, touchpad = { natural_scroll = false },
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
local animations = {
    { "global", 1, "default" }, { "border", 3.8, "easeOutQuint" }, { "windows", 3.3, "easeOutQuint" },
    { "windowsIn", 2.8, "easeOutQuint", "popin 87%" }, { "windowsOut", 1.0, "linear", "popin 87%" },
    { "fadeIn", 1.2, "almostLinear" }, { "fadeOut", 1.0, "almostLinear" }, { "fade", 2.1, "quick" },
    { "layers", 2.7, "easeOutQuint" }, { "layersIn", 2.8, "easeOutQuint", "fade" }, { "layersOut", 1.1, "linear", "fade" },
    { "fadeLayersIn", 1.25, "almostLinear" }, { "fadeLayersOut", 0.95, "almostLinear" },
    { "workspaces", 1.35, "almostLinear", "fade" }, { "workspacesIn", 0.85, "almostLinear", "fade" },
    { "workspacesOut", 1.35, "almostLinear", "fade" }, { "zoomFactor", 4.9, "quick" },
}
for _, a in ipairs(animations) do
    hl.animation({ leaf = a[1], enabled = true, speed = a[2], bezier = a[3], style = a[4] })
end

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

local function exec(command) return hl.dsp.exec_cmd(command) end
local function bind(key, dispatcher, options) hl.bind(key, dispatcher, options) end
local function key(mod, keyName) return mod:gsub(" ", " + ") .. " + " .. keyName end

hl.on("hyprland.start", function()
    hl.exec_cmd(quickshell)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
    hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
end)

bind(key(mainMod, "Return"), exec(terminal))
bind(key(mainMod, "Q"), hl.dsp.window.close())
bind(key(mainMod, "B"), exec(browser))
bind(key(mainMod, "M"), exec("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
bind(key(mainMod, "E"), exec(fileManager))
bind(key(mainMod, "F"), hl.dsp.window.float({ action = "toggle" }))
bind(key(mainMod, "SPACE"), exec("quickshell ipc call launcher toggle"))
bind(key(mainMod .. " SHIFT", "W"), exec("quickshell ipc call wallpaper toggle"))
bind(key(mainMod, "X"), exec("quickshell ipc call powermenu toggle"))
bind(key(mainMod, "P"), hl.dsp.window.pseudo())
bind(key(mainMod, "T"), hl.dsp.layout("togglesplit"))
bind(key(mainMod, "Escape"), exec("hyprlock"))

for direction, keyName in pairs({ l = "H", r = "L", u = "K", d = "J" }) do
    bind(key(mainMod, keyName), hl.dsp.focus({ direction = direction }))
    bind(key(mainMod .. " SHIFT", keyName), hl.dsp.window.move({ direction = direction }))
    bind(key(mainMod .. " CTRL", keyName), hl.dsp.window.move({ direction = direction, into_group = true }))
end
for i = 1, 10 do
    local k = i % 10
    bind(key(mainMod, tostring(k)), hl.dsp.focus({ workspace = i }))
    bind(key(mainMod .. " SHIFT", tostring(k)), hl.dsp.window.move({ workspace = i }))
end
bind(key(mainMod, "S"), hl.dsp.workspace.toggle_special("magic"))
bind(key(mainMod .. " SHIFT", "S"), hl.dsp.window.move({ workspace = "special:magic" }))
bind(key(mainMod, "mouse_down"), exec("hyprctl keyword cursor:zoom_factor 0.5"))
bind(key(mainMod, "mouse_up"), exec("hyprctl keyword cursor:zoom_factor 2.0"))
bind(key(mainMod, "mouse:272"), hl.dsp.window.drag(), { mouse = true })
bind(key(mainMod, "mouse:273"), hl.dsp.window.resize(), { mouse = true })

local locked = { locked = true }
local lockedRepeat = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && quickshell ipc call osd showVolume"), lockedRepeat)
bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && quickshell ipc call osd showVolume"), lockedRepeat)
bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && quickshell ipc call osd showVolume"), lockedRepeat)
bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), lockedRepeat)
bind("XF86MonBrightnessUp", exec("~/.config/hypr/scripts/brightness up"), locked)
bind("XF86MonBrightnessDown", exec("~/.config/hypr/scripts/brightness down"), locked)
bind("XF86AudioNext", exec("playerctl next"), locked)
bind("XF86AudioPause", exec("playerctl play-pause"), locked)
bind("XF86AudioPlay", exec("playerctl play-pause"), locked)
bind("XF86AudioPrev", exec("playerctl previous"), locked)
bind(key(mainMod .. " SHIFT", "F"), exec("hyprctl dispatch fullscreen 0"))
bind(key(mainMod, "Z"), exec("hyprctl dispatch fullscreen 1"))
bind(key(mainMod .. " SHIFT", "Z"), exec("hyprctl dispatch fullscreenstate 2 0"))
bind(key(mainMod, "G"), exec("hyprctl dispatch togglegroup"))
bind(key(mainMod, "TAB"), exec("hyprctl dispatch changegroupactive f"))
bind(key(mainMod .. " SHIFT", "TAB"), exec("hyprctl dispatch changegroupactive b"))
bind(key(mainMod, "F12"), exec("grim -g \"$(slurp)\" - | wl-copy"))
bind(key(mainMod .. " CTRL", "F12"), exec("grim - | wl-copy"))
bind(key(mainMod .. " SHIFT", "F12"), exec("grim -g \"$(slurp)\" ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png"))
bind(key(mainMod, "R"), exec("~/.config/hypr/scripts/toggle-screen-recording"))

hl.window_rule({ name = "opaque-browsers", match = { class = "^(brave-browser|zen|zen-browser)$" }, opacity = "1.0 override 1.0 override" })
hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })
hl.window_rule({ name = "move-hyprland-run", match = { class = "hyprland-run" }, move = "20 monitor_h-120", float = true })
