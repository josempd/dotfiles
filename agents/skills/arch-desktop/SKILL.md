---
name: arch-desktop
description: How the Arch Linux + Hyprland laptop and desktop are built and changed (dotfiles in ~/code/dotfiles, github.com/josempd/dotfiles). Use for any change to the OS or desktop - keybindings, top bar, launcher, lock/idle/screensaver, login screen, boot splash, themes and wallpapers, keyd, services, packages - or when debugging them.
---

# Arch + Hyprland desktop (as-18)

Laptop: Arch Linux, Hyprland 0.56 (Lua config) started through uwsm, NVIDIA RTX 5070 dGPU + AMD Radeon 880M iGPU. The look is Omarchy 3.8 (waybar, hyprlock, square borders) rebuilt by hand; Omarchy itself is not installed and is only a reference (github.com/omacom/omarchy, branch `quattro`; tag `v3.8.4` for the waybar era).

## Source of truth: ~/code/dotfiles (branch `master`)

Never edit only the live file. Change the file in `~/code/dotfiles`, copy it to its live location to test, then commit (plain message, no Co-Authored-By trailer) and push `master` to github.com/josempd/dotfiles. `local-setup.sh` must stay idempotent and reproduce everything on a fresh install, so add a step there for every new file or system change.

| Repo path | Live location | Notes |
|---|---|---|
| `hypr/hyprland.lua` | `~/.config/hypr/` | Validate: `Hyprland --verify-config -c hypr/hyprland.lua` (catches unknown dispatchers, not unknown args). API stubs: `/usr/share/hypr/stubs/hl.meta.lua`. Apply: `hyprctl reload` |
| `hypr/hypridle.conf`, `hyprlock.conf`, `screensaver.txt` | `~/.config/hypr/` | `systemctl --user restart hypridle` |
| `waybar/config.jsonc`, `style.css` | `~/.config/waybar/` | `systemctl --user restart waybar` |
| `wofi/config` | `~/.config/wofi/` | style.css is generated (see Themes) |
| `bin/*` | `~/.local/bin/` | |
| `kitty.conf`, `tmux.conf` | `~/.config/kitty/`, `~/.tmux.conf` | No `~/.XCompose`: the system table is used; a stale one with a broken include makes dead keys type nothing in kitty |
| `systemd/*` | `~/.config/systemd/user/` | Only user units go here; the setup loop copies everything in it |
| `systemd-dropins/UNIT.d/*.conf` | `~/.config/systemd/user/UNIT.d/` | Drop-ins for packaged user units; waybar gets PartOf=graphical-session.target and no start limit |
| `system/*` | `/etc/...` (sudo) | e.g. networkd wait-online `--any` drop-in |
| `keyd-default.conf` | `/etc/keyd/default.conf` (sudo) | `sudo keyd reload` |
| `sddm/*` | `/etc/sddm.conf.d/`, `/usr/share/sddm/` (sudo) | |
| `themes/templates/*` | `~/.local/share/jmpd-theme/templates/` | |

## Working constraints

- No passwordless sudo, and `sudo` has no tty here. For root steps run `pkexec CMD` (wrap with `timeout 120`): polkit-kde shows a themed password dialog and the output comes back. Never add NOPASSWD rules.
- systemd user services (waybar, hypridle, hyprpaper) have a PATH without `~/.local/bin`: use full paths in their commands, or prepend it inside scripts.
- `HYPRLAND_INSTANCE_SIGNATURE` in a long-lived shell goes stale after re-login: `export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr/ | head -1)`.
- Screenshots to check visual changes: `grim` (output is 2560x1600 at scale 1.6, so `-g` takes logical coords up to 1600x1000).
- `pgrep -f`/`pkill -f` patterns must not match the calling script's own name (`jmpd.screensaver` matched `jmpd-screensaver-launch`).
- When copying Omarchy configs, Nerd Font glyphs in the U+E000-F8FF range get lost in transcription: copy files or write glyphs as `\uXXXX` escapes, never retype them.

## Keyboard (keyd + Hyprland)

macOS layout on a PC keyboard: Left Alt = Cmd, Super = Option, Right Alt = AltGr (must stay, for Spanish typing; layout `us` variant `alt-intl`). keyd turns Cmd shortcuts into app keys (Cmd+C/V/X/Z/S...) and Cmd system shortcuts into Ctrl+Super combos that `hyprland.lua` binds. Super is the window-management key.

| Keys | Action |
|---|---|
| Super+Space, Cmd+Space | App launcher (wofi) |
| Super+T, Super+Return | Terminal (kitty) |
| Super+B | Brave (default browser) |
| Super+E | Files (nautilus) |
| Super+Q, Cmd+Q | Close window (Cmd+W closes tabs) |
| Super+arrows, Super+H/J/K/L | Focus window |
| Super+1..0, Super+Shift+1..0 | Go to / move to workspace; Ctrl+Left/Right previous/next workspace |
| Super+V / F / P | Float / fullscreen / pseudo; Super+Shift+T toggle split |
| Super+S, Super+Shift+S | Scratchpad; Cmd+M / Cmd+H send window to it |
| Cmd+Tab | Cycle windows |
| Super+Escape | Power menu (lock, suspend, log out, reboot, shut down) |
| Super+Shift+Escape | Log out (`uwsm stop`; never exit Hyprland directly, it leaves user services restart-looping) |
| Ctrl+Cmd+Q | Lock |
| Super+Shift+Space | Next wallpaper of the theme |
| Super+Ctrl+Shift+Space | Theme menu (wofi with preview thumbnails, cached in `~/.cache/jmpd-theme/previews`) |
| Super+Ctrl+V | Clipboard history (cliphist + wofi) |
| Cmd+Shift+3 / 4 | Screenshot screen / area, copied |
| Print, Cmd+Shift+5 | Area into satty, like flameshot: Enter copies and closes, Ctrl+S saves |
| Cmd+arrows | Line start/end, document top/bottom; Option+Backspace deletes a word |

keyd `[control+shift]` passes Ctrl+Shift+Left/Right through untouched (tmux pane focus); without it they inherit `[control]`'s workspace mapping plus Shift. In kitty, Shift+Enter sends Alt+Enter (`\x1b\r`) so Claude Code/Codex insert a newline, also inside tmux.

Option+arrows used to be word jumps; they were freed so Super+arrows reach Hyprland. Before adding a Super binding, check keyd's `[opt:M]` layer does not remap that key.

## Desktop pieces

- **Top bar**: waybar, adapted from Omarchy 3.8. Right side: tray expander, agent usage (`bin/jmpd-agent-usage`), Bluetooth (bluetui), network (impala; iwd + systemd-networkd), volume (wiremix), CPU (btop), battery (click = power menu). Each icon carries its own right margin (~17px).
- **Agent usage**: `jmpd-agent-usage` runs `jmpd-agent-usage-claude` and `-codex` (Omarchy's `omarchy-agent-usage-*` collectors, copied, MIT) with `--limits-only`; icon only, percentage appears above 80%; tooltip lists every limit. Claude and Codex CLIs are installed by their curl installers into `~/.local/bin`.
- **Notifications**: mako (D-Bus activated, themed via the `mako.conf` template; dunst removed). **Volume/brightness popups**: swayosd (`systemd/swayosd.service`, keys call `swayosd-client`). **Clipboard history**: `systemd/cliphist.service` (`wl-paste --watch cliphist store`), picker `bin/jmpd-clipboard`. `paccache.timer` is enabled.
- **Launcher / menus**: wofi (`--dmenu` for the power and theme menus).
- **Idle**: hypridle. Screensaver after 15 min, always (`jmpd-screensaver-launch`: one fullscreen kitty per active monitor via `hyprctl dispatch "hl.dsp.exec_cmd(cmd, { monitor = ... })"`, shared class so any key closes all; running `tte` effects on the JMPD text (`hypr/screensaver.txt`); leaving it (key or focus loss) runs `loginctl lock-session` first, since a session lock hides every other window and the animation cannot play under hyprlock; tte via `uv tool install terminaltexteffects`). Lock (hyprlock) after 5 min only on battery, and before sleep. `ac-no-sleep` holds a logind *sleep* inhibitor on AC (not idle); `ac-no-sleep --on-ac` exits 0 on AC.
- **Login screen**: SDDM with Omarchy's theme (logo replaced by "JMPD" text in `#89b4fa`), greeter running on a minimal Hyprland (`sddm/10-wayland.conf`, `sddm/hyprland.lua`). Session to pick: "Hyprland (uwsm-managed)".
- **GPUs**: the internal panel (eDP) is wired to the AMD iGPU (PCI 05:00.0, card2) but NVIDIA (04:00.0) is boot_vga. Anything on Xorg picks NVIDIA and shows a blank screen: keep the greeter on Wayland.
- **Desktop (RTX 3090 only, Ryzen 5600X)**: `setup_nvidia_desktop` in local-setup.sh runs only when NVIDIA is the only display-class PCI device (`nvidia_only`): nvidia-open-dkms, early KMS (`system/nvidia-mkinitcpio.conf`, `system/nvidia-modprobe.conf`), and the Samsung TV's patched EDID plus `nvidia_modeset` HDMI params on the kernel cmdline (`system/nvidia-cmdline.conf`, `system/edid/`); without them the TV's 4K@60 link drops. hyprland.lua sets the NVIDIA env (`NVD_BACKEND`, `LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`) by the same test. `ac-no-sleep` counts a machine with no battery of its own (peripheral batteries have scope Device) as on AC.
- **Gaming**: multilib enabled, `steam` with the lib32 twins of the installed GPU drivers (`setup_steam`). Steam and `steam_app_*` windows inhibit idle while fullscreen; `misc.exit_window_retains_fullscreen` keeps Big Picture fullscreen after a game exits; `bin/jmpd-xwayland-primary` makes the Samsung TV the X primary at Hyprland start, so fullscreen XWayland games size to its 4K instead of the ultrawide.
- **Boot**: systemd-boot with UKIs, Arch's default splash. No Plymouth.
- **Window buttons**: on the left, `close,maximize:` (gsettings `org.gnome.desktop.wm.preferences button-layout` + the `gtk-settings.ini` theme template). No minimize: Hyprland has no minimized state. Electron apps (Obsidian, Slack) draw their own buttons and ignore it.
- **Web apps**: `applications/*.desktop` running `brave --app=URL --class=NAME`, icons in `applications/icons/` (from Omarchy) installed to `~/.local/share/icons/hicolor/512x512/apps`. WhatsApp is one.
- **Lid**: logind ignores it (`system/logind-lid.conf` → `/etc/systemd/logind.conf.d/lid.conf`, applied with `systemctl kill -s HUP systemd-logind`); Hyprland `switch:on/off:Lid Switch` binds turn eDP-1 off/on with `hl.dsp.dpms`.
- **Network**: systemd-networkd + iwd. `systemd-networkd-wait-online` is masked: docker pulls in network-online.target, so with no known wifi at boot graphical.target waited 2 min and uwsm refused to start Hyprland from SDDM. Nothing should block boot on the network.

## Reinstall keeping @home

Done on the desktop 2026-10-27. pacstrap `base linux linux-firmware amd-ucode btrfs-progs cryptsetup dosfstools efibootmgr openssh iwd git sudo neovim zsh`, then `local-setup.sh`. `linux.preset` needs `PRESETS=('default' 'fallback')` for the fallback UKI; run `sudo bootctl install` after first boot (it cannot write firmware entries from the chroot); `/boot` in fstab with `fmask=0077,dmask=0077`.

Omarchy files left in ~ (from before the reinstall) point at `/usr/share/omarchy` and fail silently: the known ones were removed by hand; for new oddities, grep ~ for `omarchy` paths that no longer exist.

## Themes

`jmpd-theme` applies Omarchy themes: it reads a theme's `colors.toml` (from a sparse clone at `~/.local/share/omarchy-themes`, or user themes in `~/.config/jmpd-theme/themes/NAME`) and renders `themes/templates/*` into waybar `theme.css`, hypr `theme.lua` (border colors, loaded by hyprland.lua), `hyprlock-theme.conf`, `hyprpaper.conf`, kitty `current-theme.conf`, wofi `style.css`, mako `config`, swayosd `style.css`, GTK 3/4 `settings.ini` and qt6ct (`qt6ct.conf` + `colors/jmpd.conf`, a Fusion palette; `QT_QPA_PLATFORMTHEME=qt6ct` comes from `uwsm-env` → `~/.config/uwsm/env`, so Qt apps like the polkit dialog follow the theme), sets gsettings `icon-theme` (and GTK `gtk-icon-theme-name`) from the theme's `icons.theme`, a Yaru color from `yaru-icon-theme` (AUR), falling back to Adwaita when absent or not installed, and gsettings `color-scheme` (prefer-dark/light from the theme's `mode`, which the portal hands to Chrome, Electron and libadwaita apps) and `gtk-theme`, then reloads. Commands: `jmpd-theme` (menu), `set NAME`, `bg-next`, `reapply` (after editing templates), `list`, `update`. Never put colors directly in waybar/wofi/hyprlock/hyprland configs: add a `{{ key }}` (or `{{ key_strip }}` for hex without `#`) to a template. Neovim is not themed. The hyprpaper splash text is disabled in its template.
