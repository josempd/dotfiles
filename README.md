# Local Setup

Bootstrap script and dotfiles for Arch Linux + Hyprland.

## Usage

```bash
git clone https://github.com/josempd/dotfiles.git ~/localsetup
cd ~/localsetup
chmod +x jmpd.sh
./jmpd.sh
```

The script is idempotent — safe to re-run at any time. It will skip anything already installed.

## What it does

1. **Packages** — shell and CLI tools (zsh, ripgrep, fd, fzf, jq, bat, delta, lazygit, glow, tmux, wl-clipboard, eza, zoxide, btop, fastfetch, tldr, plocate), kitty, neovim, bluez, keyd, the Hyprland desktop pieces (PipeWire audio, hyprlock, hypridle, hyprpaper, waybar, wofi, hyprpicker, impala, bluetui, wiremix, hyprsunset, satty, brightnessctl, playerctl, gnome-keyring, Nerd and Noto fonts), apps (Nautilus, imv, mpv, Evince, Obsidian, Telegram, Zed, Spotify), Go, mise, uv, Docker (buildx, compose), kubectl, kubectx, k9s, helm, kubeseal, argocd, aws-cli-v2, terraform, sshpass, openfortivpn, tailscale, all from the official repos with pacman; enables Bluetooth and power profiles, turns on ufw (deny incoming)
2. **Default shell** — sets zsh as the login shell
3. **Oh My Zsh** — framework + plugins (autosuggestions, syntax-highlighting)
4. **Powerlevel10k** — zsh theme
5. **mise** — Node 24, Python 3.14 (+3.11), pnpm, bun and pi from `mise/global.toml`; `uv/uv.toml` makes uv use mise's Pythons
6. **Docker** — enables the service and adds you to the `docker` group
7. **Kitty** — config and Catppuccin theme
8. **Neovim** — config from `nvim/` (kickstart.nvim + catppuccin, LSPs, neo-tree, agentic opts)
8b. **Hyprland** — `hypr/hyprland.lua` (macOS-style shortcuts, paired with keyd), hypridle/hyprlock, the Omarchy 3.8-style waybar and wofi, the tte screensaver, and the first theme through `jmpd-theme`; enables waybar, hyprpaper and hypridle as user services. Also the SDDM login screen (Omarchy theme, Wayland greeter)
9. **Claude Code** and **Codex** — official installers; `agents/skills/` is linked into `~/.claude/skills` and `~/.codex/skills`
10. **AUR apps** — Brave (`brave-bin`), Slack (`slack-desktop`) and LastPass CLI (`lastpass-cli`) through yay
11. **Default apps** — Papers as the default PDF viewer
12. **keyd** — macOS layout from `keyd-default.conf`: Left Alt is Cmd, Super is Option
13. **Dotfiles** — `zshrc`, `p10k.zsh`, `gitconfig`, `tmux.conf`
14. **Scripts and services** — `bin/` into `~/.local/bin` (agentdev, nvim-open, cursor, update-cursor, ac-no-sleep, claude-desktop-wayland, and the jmpd-* desktop scripts), `systemd/` user units (ac-no-sleep, daily Cursor update), `applications/nvim-remote.desktop`, and the `udev/` Bluetooth rule

Not covered, install by hand: worktrunk (`wt`), Cursor (run `update-cursor` once), Claude Desktop.

## Personalize before running

Fork/clone this repo and edit the following files:

| File | What to change |
|---|---|
| `gitconfig` | Your `name` and `email` |
| `zshrc` | Shell aliases, environment variables, plugins list — sources `~/.zshrc.local` (untracked) for machine-local/work config and secrets |
| `p10k.zsh` | Powerlevel10k prompt style (or re-run `p10k configure`) |
| `kitty.conf` | Terminal font, theme, keybindings |
| `nvim/` | Neovim config — copied to `~/.config/nvim` |
| `jmpd.sh` | AUR app list, packages, or any steps you don't need |

## Adding a new step

1. Drop any config files in this directory.
2. Add a `setup_X` function in `jmpd.sh`.
3. Call it from `main`.

## Post-install: Bluetooth keyboard stability (Realtek adapters)

Realtek USB Bluetooth adapters (e.g. `0bda:b86a`) ship with aggressive USB autosuspend enabled (`power/control=auto`, `autosuspend_delay_ms=2000`). This causes BLE keyboards to disconnect after seconds of inactivity — the adapter sleeps, drops the HID link, and reconnects with a new device handle. Symptoms: random disconnects, repeated/ghost keystrokes, ~30s reconnection gaps.

**Immediate fix (until reboot):**

```bash
sudo sh -c 'echo on > /sys/bus/usb/devices/3-3/power/control && echo -1 > /sys/bus/usb/devices/3-3/power/autosuspend_delay_ms'
```

> Note: the USB device path (`3-3`) may differ — find yours with `grep -rl "Bluetooth" /sys/bus/usb/devices/*/product`.

**Persistent fix (survives reboots):**

```bash
sudo tee /etc/udev/rules.d/99-bt-no-autosuspend.rules <<< 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="b86a", ATTR{power/control}="on", ATTR{power/autosuspend_delay_ms}="-1"'
```

## Requirements

- A fresh Arch install with a user that has `sudo`
- Not run as root — the script prompts for sudo when needed

## For AI agents

`agents/skills/arch-desktop/SKILL.md` describes how this desktop is put together (keybindings, bar, themes, idle, login, GPUs) and how to change it. Read it before touching the OS setup.
