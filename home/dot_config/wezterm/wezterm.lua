-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 14

--config.enable_tab_bar = false

config.window_decorations = "RESIZE"

--config.color_scheme = "Github Dark (Gogh)"
config.color_scheme = "Google (dark) (terminal.sexy)"

config.window_background_opacity = 0.8
config.macos_window_background_blur = 10

return config
