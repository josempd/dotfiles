---
name: arch-desktop
description: How the Arch Linux + Hyprland desktop is built and changed (dotfiles in ~/code/dotfiles, github.com/josempd/dotfiles). Use for any change to the OS or desktop - keybindings, top bar, launcher, lock/idle/screensaver, login screen, themes and wallpapers, keyd, audio, services, packages - or when debugging them.
---

# Arch + Hyprland desktop

Desktop: Arch Linux, Hyprland 0.56 (Lua config) started through uwsm, RTX 3090 as the only GPU (Ryzen 5600X), Samsung 4K TV on the left (HDMI, scale 2) and Lenovo R45w-30 32:9 at 165Hz on the right. The look is Omarchy 3.8 rebuilt by hand; Omarchy is not installed, only a reference (github.com/omacom/omarchy, branch `quattro`). `master` is desktop-only; laptop support (AMD iGPU + NVIDIA, lid, battery) is frozen on the `laptop` branch.

## Source of truth: ~/code/dotfiles (branch `master`)

`jmpd.sh` converges the machine to the repo and is safe to re-run. Its `FILES` manifest maps every repo path to its live location (dirs map one-to-one, tracked files only); `PACKAGES` holds repo and AUR packages, installed in one `yay` transaction. Workflow for any change:

1. Edit the repo file, copy it live (or run `./jmpd.sh`) and test it.
2. `./check.sh` must print `ok` (it is also the pre-commit hook).
3. Commit with a conventional message (lowercase, ≤100 chars, no Co-Authored-By trailer), push `master`.

Apply commands: `hyprctl reload` (validate first: `Hyprland --verify-config -c hypr/hyprland.lua`, API stubs in `/usr/share/hypr/stubs/hl.meta.lua`), `systemctl --user restart waybar|hypridle|xdg-desktop-portal-hyprland`, `sudo keyd reload`. Restarting pipewire kills live audio streams; config changes there wait for the next login.

## MVI rules (minimum viable interface)

Enforced by `check.sh`:

1. Every tracked file is installed by `jmpd.sh` (a `FILES` entry or a literal path), and every manifest source exists.
2. Every `bin/` script and `systemd/` unit is referenced somewhere else in the repo.
3. No guards for things `jmpd.sh` installs (`command -v`, `have`, `[[ -f ]]` on our own files); only the curl installers check first.
4. One place per concern: `PATH` only in `uwsm-env` (session, services, Hyprland) and `zshrc`; `~/.local/bin/` paths only in unit `ExecStart` lines (`%h/`); hex colors only in `themes/templates/` (exceptions: tmux, sddm, nvim).
5. No unit in `systemd/` with the name of a packaged one; drop-ins in `systemd-dropins/` carry only what the packaged unit lacks.
6. Comments are one line, never blocks; no commented-out code.
7. Static checks pass: `bash -n` and `shellcheck` on shell scripts, Python parses, `Hyprland --verify-config` for both Lua configs, waybar JSONC parses, `systemd-analyze --user verify`.
8. No drift: every live copy matches the repo, and no `jmpd-*` script or user unit lives without a repo file (`llama-server.service` is the one machine-local exception).
9. `vendor/` is upstream code, never edited: its checksum is recorded in `vendor/omarchy-agents/UPSTREAM`.

Not checked by script:

- `jmpd.sh` describes only the target state. One-off migrations (old files to delete, packages to remove) are run by hand and written in the commit body.
- Deleting a repo file means deleting its live copy in the same change.
- Configs carry only keys that differ from upstream defaults.
- New features reuse what exists (`put`, the manifest, jmpd-theme templates, `uwsm-app --`) instead of adding helpers.

## Working constraints

- No passwordless sudo, and `sudo` has no tty for agents. For root steps run `timeout 120 pkexec CMD` with absolute paths (pkexec resets the cwd); polkit-kde shows a themed dialog. AUR installs: `yay -S --sudo pkexec PKG`. Never add NOPASSWD rules. `jmpd.sh` itself needs a real terminal.
- `HYPRLAND_INSTANCE_SIGNATURE` in a long-lived shell goes stale after re-login: `export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr/ | head -1)`.
- `uwsm-env` is read at login; a running session picks up changes only after logging out and back in.
- Screenshots to check visual changes: `grim -o <output>` (TV is 1920x1080 logical, the Lenovo 5120x1440).
- `pgrep -f`/`pkill -f` patterns must not match the calling script's own command line.
- Nerd Font glyphs (U+E000-F8FF) get lost in transcription: copy files or write `\uXXXX` escapes, never retype them.
- `/usr/bin/python3` has python-gobject; `python3` on PATH is mise's and does not.

## Keyboard (keyd + Hyprland)

macOS layout on a PC keyboard: Left Alt = Cmd, Super = Option, Right Alt = AltGr (layout `us` variant `alt-intl`, for Spanish; the SDDM greeter uses the same). keyd turns Cmd shortcuts into app keys (Cmd+C/V become Ctrl+Insert/Shift+Insert) and Cmd system shortcuts into Ctrl+Super combos that `hyprland.lua` binds. Super is the window key.

| Keys | Action |
|---|---|
| Super+Space, Cmd+Space | App launcher (wofi) |
| Super+T, Super+Return | Terminal (kitty, always inside tmux) |
| Super+B / Super+E | Brave / Files (nautilus) |
| Super+Q, Cmd+Q | Close window (Cmd+W closes tabs) |
| Super+arrows, Super+H/J/K/L | Focus window |
| Super+1..0, Super+Shift+1..0 | Go to / move to workspace; Ctrl+Left/Right previous/next |
| Super+V / F / P | Float / fullscreen / pseudo; Super+Shift+T toggle split |
| Super+S, Super+Shift+S | Scratchpad; Cmd+M / Cmd+H send window to it |
| Cmd+Tab | Cycle windows |
| Super+Escape | Power menu (lock, suspend, log out, reboot, shut down) |
| Super+Shift+Escape | Log out (`uwsm stop`; never exit Hyprland directly) |
| Ctrl+Cmd+Q | Lock |
| Super+Shift+Space / Super+Ctrl+Shift+Space | Next wallpaper / theme menu |
| Super+Ctrl+V | Clipboard history (cliphist + wofi) |
| Super+Ctrl+B / A / W / T | bluetui / wiremix / impala / btop, same as the bar icons |
| Cmd+Shift+3 / 4 | Screenshot screen / area, copied |
| Print, Cmd+Shift+5 | Area into satty: Enter copies and closes, Ctrl+S saves |
| Cmd+arrows | Line start/end, document top/bottom; Option+Backspace deletes a word |

keyd `[control+shift]` passes Ctrl+Shift+Left/Right through (tmux pane focus). In kitty, Shift+Enter sends Alt+Enter so Claude Code/Codex insert a newline, also inside tmux. Before adding a Super binding, check keyd's `[opt:M]` layer does not remap that key.

## Desktop pieces

- **Top bar**: waybar from Omarchy 3.8. Right side: tray expander, agents, memory pressure (`jmpd-mem-pressure --waybar`), Bluetooth, network (iwd + systemd-networkd), volume, CPU. Clicks open TUIs through `uwsm-app -- kitty -e ...`.
- **Agent usage**: Omarchy's collectors, vendored unmodified in `vendor/omarchy-agents/` and installed to `~/.local/share/jmpd-agents`. `jmpd-agents update` runs them and writes `~/.local/state/jmpd-agents/usage/<id>.json`; `jmpd-agents waybar` is the bar icon (highest limit once above 80%, every limit in the tooltip); `jmpd-agents panel` is the GTK4 window (app-id `dev.jmpd.AgentsPanel`, colors from the `agents-panel.css` template). `agents-local.json` makes pi's `llama-local` provider count as Local models. To update the collectors: copy upstream over, review the diff, record the new commit and checksum in `UPSTREAM`.
- **Notifications**: mako (D-Bus activated, `mako.conf` template). Volume popups: swayosd (`systemd/swayosd.service`). Clipboard: the packaged `cliphist.service`, picker `jmpd-clipboard`.
- **Idle**: hypridle starts the screensaver after 15 min (`jmpd-screensaver-launch`: one fullscreen kitty per monitor running `tte` on `hypr/screensaver.txt`); a key or focus loss locks first, since the lock hides every window. Locks before sleep. Steam and `steam_app_*` windows inhibit idle while fullscreen.
- **Login**: SDDM with Omarchy's theme and the JMPD.SH logo, greeter on a minimal Hyprland (`sddm/conf.d/10-wayland.conf`, `sddm/hyprland.lua`); `jmpd.sh` preselects the user and "Hyprland (uwsm-managed)".
- **NVIDIA**: nvidia-open-dkms with early KMS (`system/nvidia-mkinitcpio.conf`, `system/nvidia-modprobe.conf`), NVIDIA env in `uwsm-env`. The TV needs its patched EDID plus `nvidia_modeset` HDMI params on the kernel cmdline (`system/nvidia-cmdline.conf`, merged token by token into `/etc/kernel/cmdline`; also `zswap.enabled=0`), or its 4K@60 link drops. Workspace 1 is pinned to the TV and 2 to the Lenovo so a link drop never moves a fullscreen game.
- **Audio**: the NVIDIA HDA card offers only the TV profile (`pipewire/nvidia-hdmi-tv.profile-set.conf` + `wireplumber/nvidia-hdmi-tv-profile.conf`); the Lenovo is a static sink on `hw:NVidia,7` (`pipewire/10-nvidia-hdmi-lenovo.conf`) whose IEC958 switch a pipewire drop-in unmutes. The KEF LSX II never suspends; Bluetooth auto-connects A2DP.
- **Memory**: zram the size of RAM, sysctl reclaim tuned for it, systemd-oomd killing the worst app scope or tmux pane before the kernel OOM killer (`system/`, `systemd-dropins/`).
- **Local LLM**: `setup_llama_server` builds `~/llama.cpp` with CUDA at the pinned `ref` (move `ref` to upgrade; the build reruns). Models in `~/models` are fetched by hand. qwen for coding runs on demand via `~/code/pi-harness/scripts/llama-serve.sh` (127.0.0.1:8080). Claudia's brain is `~/.config/systemd/user/llama-server.service` (machine-local, disabled).
- **Gaming**: multilib, steam with lib32-nvidia-utils. `misc.exit_window_retains_fullscreen` keeps Big Picture fullscreen after a game exits; `jmpd-xwayland-primary` makes the TV the X primary at Hyprland start, so XWayland games size to its 4K.
- **Apps**: Cursor from AUR `cursor-bin` (flags in `cursor-flags.conf`), Brave flags in `brave-flags.conf`. Web apps are `applications/*.desktop` running `brave --app=URL --class=NAME`, icons in `icons/`.
- **Window buttons**: `close,maximize:` on the left (gsettings + the `gtk-settings.ini` template). No minimize: Hyprland has no minimized state.
- **Boot and network**: systemd-boot with UKIs, no Plymouth. systemd-networkd + iwd; `systemd-networkd-wait-online` is masked, so nothing blocks boot on the network.

## Themes

`jmpd-theme` applies Omarchy themes: it reads a theme's `colors.toml` (sparse clone at `~/.local/share/omarchy-themes`, or `~/.config/jmpd-theme/themes/NAME`) and renders `themes/templates/*` into the waybar, hypr borders (`theme.lua`), hyprlock, hyprpaper, kitty, wofi, mako, swayosd, share picker, agents panel, btop, GTK and qt6ct configs. It also sets the gsettings icon theme (a Yaru color), `color-scheme` and `gtk-theme`, then reloads everything. Commands: `jmpd-theme` (menu), `set NAME`, `bg-next`, `reapply` (after editing templates; `jmpd.sh` runs it), `list`, `update`. Colors go into templates as `{{ key }}` (or `{{ key_strip }}` for hex without `#`), never into the configs. tmux and Neovim are not themed.

## Reinstall keeping @home

Done 2026-10-27: pacstrap `base linux linux-firmware amd-ucode btrfs-progs cryptsetup dosfstools efibootmgr openssh iwd git sudo neovim zsh`, clone this repo, run `./jmpd.sh` from a terminal (it bootstraps yay). `linux.preset` needs `PRESETS=('default' 'fallback')`; run `sudo bootctl install` after first boot; `/boot` in fstab with `fmask=0077,dmask=0077`. Files left in ~ by older setups (Omarchy) fail silently: grep ~ for paths that no longer exist.
