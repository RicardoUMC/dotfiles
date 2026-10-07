-- Import the wezterm API
local wezterm = require("wezterm")
local config = {}

config.check_for_updates = true

config.window_padding = {
    top = 5,
    right = 5,
    left = 5,
    bottom = 5,
}

-- config.background = {
--     {
--         source = {
--             File = "~/OneDrive/Fotos/Wallpapers/abstract.png", -- Path to the background image file
--             -- File = "~/OneDrive/Fotos/Wallpapers/neon-sign.jpg", -- Path to the background image file
--         },
--         width = "100%", -- Set the background image width to 100% of the terminal window
--         height = "100%", -- Set the background image height to gg100% of the terminal window
--         opacity = 1.0, -- Set the opacity of the background image (0.0 - 1.0)
--         hsb = {
--             brightness = 0.10, -- Set the brightness of the background image (low value to darken the image)
--             saturation = 1, -- Set the saturation of the background image
--         },
--     },
-- }

-- config.colors = {
--     foreground = "#D8E2EC",
--     background = "#181A1B",
--     cursor_bg = "#539AFC",
--     cursor_border = "#539AFC",
--     cursor_fg = "#0F1419",
--     selection_bg = "#1D252C",
--     selection_fg = "#D8E2EC",
--
--     ansi = {
--         "#1D252C", -- black
--         "#C44659", -- red
--         "#79CD8D", -- green
--         "#FF9E64", -- yellow
--         "#4690F7", -- blue
--         "#A41D55", -- magenta
--         "#60CFD6", -- cyan
--         "#B7C5D3", -- white
--     },
--
--     brights = {
--         "#28323A", -- bright black
--         "#D95468", -- bright red
--         "#8BD49C", -- bright green
--         "#EBBF83", -- bright yellow
--         "#539AFC", -- bright blue
--         "#B62D65", -- bright magenta
--         "#70E1E8", -- bright cyan
--         "#FBFBFD", -- bright white
--     },
-- }
-- config.color_scheme = 'Tokyo Night'

-- Set the terminal font
-- config.font = wezterm.font("Cascadia Code")
-- config.font = wezterm.font_with_fallback({ "Cascadia Code", "CaskaydiaCove NF" })
-- config.font = wezterm.font("FiraCode Nerd Font")
-- config.font = wezterm.font("Liga SFMono Nerd Font")
-- config.font = wezterm.font("Iosevka NF")
config.font = wezterm.font_with_fallback({
    { family = "VictorMono Nerd Font", weight = "Regular" },
    { family = "JetBrains Mono", weight = "Regular" },
    { family = "FiraCode Nerd Font", weight = "Regular" },
})

config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.max_fps = 120
config.window_decorations = "NONE"

-- Font Size
config.font_size = 12

-- Enable Kitty Graphics
config.enable_kitty_graphics = true

-- Background with Transparency
-- config.window_background_opacity = 0.45
-- config.win32_system_backdrop = "Acrylic" -- Only Works in Windows
-- config.win32_acrylic_accent_color = "#222436"
-- config.win32_system_backdrop = "Disable"

-- Soften opacity change on focus/unfocus
wezterm.on("window-focus-changed", function(window)
    local overrides = window:get_config_overrides() or {}
    if window:is_focused() then
        overrides.window_background_opacity = 0.85
        -- overrides.win32_system_backdrop = "Acrylic"
        overrides.color_scheme = "Tokyo Night"
    else
        overrides.window_background_opacity = 0.75
        -- overrides.win32_system_backdrop = "Disable"
        overrides.color_scheme = "Tokyo Night (Gogh)"
    end
    window:set_config_overrides(overrides)
end)

-- Disable Scroll Bar
config.enable_scroll_bar = false

-- Never ask for close confirmations
config.window_close_confirmation = "NeverPrompt"
-- config.default_prog = { "pwsh.exe", "-NoLogo" }

-- Activate ONLY if windows --
-- config.front_end = "OpenGL"
local gpus = wezterm.gui.enumerate_gpus()
if #gpus > 0 then
    config.webgpu_preferred_adapter = gpus[1] -- only set if there's at least one GPU
else
    -- fallback to default behavior or log a message
    wezterm.log_info("No GPUs found, using default settings")
end

-- Performance and scrollback
config.animation_fps = 120
config.scrollback_lines = 15000

-- Tabs and UI polish
config.hide_tab_bar_if_only_one_tab = true
config.window_frame = { active_titlebar_bg = "#181A1B" }

-- Simple tab titles: use pane title
wezterm.on("format-tab-title", function(tab)
    return tab.active_pane.title
end)

-- Home as initial directory
-- config.default_cwd = os.getenv("USERPROFILE")

-- Launch menu: Windows profiles and Git Bash
-- config.launch_menu = {
--     { label = "PowerShell", args = { "pwsh.exe", "-NoLogo" } },
--     { label = "WSL: Kali", args = { "wsl.exe", "-d", "kali-linux" } },
--     { label = "WSL: Ubuntu", args = { "wsl.exe", "-d", "Ubuntu" } },
--     { label = "Git Bash", args = { "C:/Program Files/Git/bin/bash.exe", "-l" } },
-- }

-- WSL domains (Ubuntu, Kali)
-- config.wsl_domains = {
--     { name = "WSL:Ubuntu", distribution = "Ubuntu" },
--     { name = "WSL:Kali", distribution = "kali-linux" },
-- }
-- config.default_domain = "local"

-- SSH domains
-- config.ssh_domains = {
--     -- Add your servers here; examples:
--     { name = "dev-server", remote_address = "user@dev.example.com", multiplexing = "None" },
--     { name = "home-nas", remote_address = "user@192.168.1.10", multiplexing = "None" },
-- }

local function basename(path)
    if not path then
        return ""
    end

    return path:gsub("\\", "/"):match("([^/]+)$") or path
end

local function is_editor_process(pane)
    local user_vars = pane:get_user_vars()
    if user_vars.IS_NVIM == "true" then
        return true
    end

    local process_name = basename(pane:get_foreground_process_name()):lower()

    return process_name == "nvim"
        or process_name == "vim"
        or process_name == "view"
        or process_name == "lvim"
        or process_name == "nvim.exe"
        or process_name == "vim.exe"
end

local function activate_pane_or_send_key(direction, key)
    return wezterm.action_callback(function(window, pane)
        if is_editor_process(pane) then
            window:perform_action(wezterm.action.SendKey({ key = key, mods = "CTRL" }), pane)
            return
        end

        window:perform_action(wezterm.action.ActivatePaneDirection(direction), pane)
    end)
end

-- Productive keybindings with mux, splits, and nvim-aware pane navigation.
config.keys = {
    { key = "T", mods = "CTRL|SHIFT", action = wezterm.action.SpawnTab("DefaultDomain") },
    { key = "W", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab({ confirm = false }) },

    { key = "r", mods = "CTRL|SHIFT", action = wezterm.action.SplitPane({ direction = "Right" }) },
    { key = "d", mods = "CTRL|SHIFT", action = wezterm.action.SplitPane({ direction = "Down" }) },
    {
        key = "Enter",
        mods = "CTRL|SHIFT",
        action = wezterm.action.Multiple({
            wezterm.action.SplitPane({ direction = "Down", size = { Percent = 35 } }),
            wezterm.action.TogglePaneZoomState,
        }),
    },
    { key = "q", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentPane({ confirm = false }) },

    { key = "h", mods = "CTRL", action = activate_pane_or_send_key("Left", "h") },
    { key = "l", mods = "CTRL", action = activate_pane_or_send_key("Right", "l") },
    { key = "k", mods = "CTRL", action = activate_pane_or_send_key("Up", "k") },
    { key = "j", mods = "CTRL", action = activate_pane_or_send_key("Down", "j") },
    { key = "z", mods = "CTRL|SHIFT", action = wezterm.action.TogglePaneZoomState },

    { key = "f", mods = "CTRL|SHIFT", action = wezterm.action.Search({ CaseSensitiveString = "" }) },
    { key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
    { key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },

    { key = "u", mods = "CTRL|SHIFT", action = wezterm.action.SwitchToWorkspace },
    { key = "n", mods = "CTRL|SHIFT", action = wezterm.action.SwitchWorkspaceRelative(1) },
    { key = "p", mods = "CTRL|SHIFT", action = wezterm.action.SwitchWorkspaceRelative(-1) },
    {
        key = "a",
        mods = "CTRL|SHIFT",
        action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|TABS|WORKSPACES" }),
    },
    {
        key = "m",
        mods = "CTRL|SHIFT",
        action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }),
    },

    {
        key = "o",
        mods = "CTRL|SHIFT",
        action = wezterm.action.SpawnCommandInNewWindow({
            args = { wezterm.executable_dir .. "/wezterm", "start", "--always-new-process", "--attach", "current-pane" },
        }),
    },
    -- { key = "p", mods = "CTRL|SHIFT", action = wezterm.action.ActivateCommandPalette },
}

-- Quick tab switching Alt+1..9
for i = 1, 9 do
    table.insert(config.keys, { key = tostring(i), mods = "ALT", action = wezterm.action.ActivateTab(i - 1) })
end

-- Return the final config
return config
