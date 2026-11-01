-- Minimal Hyprland for the SDDM greeter: same keyboard as the session, so passwords type the same
hl.config({
  input = {
    kb_layout = "us",
    kb_variant = "alt-intl",
    kb_options = "lv3:ralt_switch",
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    background_color = "rgb(000000)",
    force_default_wallpaper = 0,
  },

  animations = {
    enabled = false,
  },
})
