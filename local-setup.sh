#!/usr/bin/env bash
# ~/localsetup/local-setup.sh
# Personal local setup script for Arch Linux

set -euo pipefail

# ─── Helpers ──────────────────────────────────────────────────────────────────

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()      { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
skip()    { printf "\033[1;90m[SKIP]\033[0m %s\n" "$*"; }
warn()    { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()     { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }

# Refuse to run as root — sudo is requested per-command instead.
if [[ $EUID -eq 0 ]]; then
    err "Do not run this script as root. It will prompt for sudo when needed."
    exit 1
fi

# Has command in PATH?
have() { command -v "$1" >/dev/null 2>&1; }

# Install a file into place, creating destination directory if needed.
# Backs up existing files with a timestamp.
install_file() {
    local src="$1"
    local dest="$2"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    if [[ ! -f "$src" ]]; then
        err "Source file not found: $src"
        return 1
    fi

    if [[ ! -d "$dest_dir" ]]; then
        info "Creating directory: $dest_dir"
        mkdir -p "$dest_dir"
    fi

    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
        skip "Already up to date: $dest"
        return 0
    fi

    if [[ -f "$dest" ]]; then
        local backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "Backing up existing file to: $backup"
        cp "$dest" "$backup"
    fi

    cp "$src" "$dest"
    ok "Installed: $dest"
}

# Install a directory tree into place. Backs up an existing, different tree with a timestamp.
install_dir() {
    local src="$1"
    local dest="$2"

    if [[ -d "$dest" ]] && diff -rq "$src" "$dest" >/dev/null 2>&1; then
        skip "Already up to date: $dest"
        return 0
    fi

    if [[ -e "$dest" ]]; then
        local backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "Backing up existing directory to: $backup"
        mv "$dest" "$backup"
    fi

    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    ok "Installed: $dest"
}

# Clone a git repo into a destination if it doesn't already exist.
git_clone_if_missing() {
    local url="$1"
    local dest="$2"
    local depth="${3:-}"

    if [[ -d "$dest/.git" ]]; then
        skip "Repo already cloned: $dest"
        return 0
    fi

    info "Cloning $url -> $dest"
    if [[ -n "$depth" ]]; then
        git clone --depth="$depth" "$url" "$dest"
    else
        git clone "$url" "$dest"
    fi
    ok "Cloned: $dest"
}

# Ensure an AUR package is installed (yay builds as the user and asks for sudo itself).
aur_ensure() {
    local pkg="$1"
    if pacman -Qq "$pkg" >/dev/null 2>&1; then
        skip "AUR package already installed: $pkg"
        return 0
    fi
    info "Installing from AUR: $pkg"
    yay -S --needed --noconfirm "$pkg"
    ok "Installed from AUR: $pkg"
}

# Ensure packages from the official repos are installed.
pkg_ensure() {
    local missing=()
    local pkg
    for pkg in "$@"; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
            skip "package already installed: $pkg"
        else
            missing+=("$pkg")
        fi
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0
    info "Installing: ${missing[*]}"
    if sudo pacman -S --needed --noconfirm "${missing[@]}"; then
        ok "Installed: ${missing[*]}"
        return 0
    fi

    # One unknown name fails the whole transaction; retry one by one so the rest still install.
    warn "Batch install failed — retrying one package at a time"
    local failed=()
    for pkg in "${missing[@]}"; do
        sudo pacman -S --needed --noconfirm "$pkg" || failed+=("$pkg")
    done
    [[ ${#failed[@]} -eq 0 ]] || err "Not installed (check the name with pacman -Ss): ${failed[*]}"
}

# ─── Steps ────────────────────────────────────────────────────────────────────

# 1. Packages
setup_packages() {
    info "Setting up packages..."
    # multilib carries Steam and the 32-bit GPU drivers it needs
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
        ok "multilib enabled"
    fi
    sudo pacman -Syu --noconfirm

    local packages=(
        # Base and shell
        zsh git curl wget ca-certificates base-devel unzip
        ripgrep fd fzf jq bat git-delta lazygit glow wl-clipboard tmux
        kitty neovim bluez bluez-utils keyd openssh github-cli
        eza zoxide btop fastfetch tldr man-db less plocate pacman-contrib

        # Hyprland desktop: audio, lock/idle, bar, launcher, screenshots, media keys, fonts
        # (the session itself too, so a bare pacstrap install is enough to start from)
        hyprland uwsm sddm xdg-desktop-portal-hyprland polkit-kde-agent qt6-wayland zram-generator
        wireplumber pipewire-pulse pipewire-alsa pipewire-jack
        hyprlock hypridle hyprpaper waybar wofi hyprpicker hyprsunset satty
        impala bluetui wiremix mako libnotify cliphist swayosd xorg-xrandr
        brightnessctl playerctl power-profiles-daemon ufw
        gnome-keyring xdg-desktop-portal-gtk
        ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji

        # Apps
        nautilus sushi imv mpv evince obsidian telegram-desktop zed spotify-launcher

        # Languages and runtimes (Node and Bun come from their own installers below)
        go pyenv uv python

        # Containers and Kubernetes
        docker docker-buildx docker-compose
        kubectl kubectx k9s helm kubeseal argocd

        # Cloud, secrets, VPN
        aws-cli-v2 terraform sshpass openfortivpn tailscale
    )

    pkg_ensure "${packages[@]}"

    sudo systemctl enable --now bluetooth.service power-profiles-daemon.service
    # Weekly cleanup of old package downloads (pacman-contrib)
    sudo systemctl enable --now paccache.timer
    # mako is the notification daemon; dunst would compete for the same D-Bus name
    if pacman -Qq dunst &>/dev/null; then
        sudo pacman -Rns --noconfirm dunst
    fi

    # Closing the lid does nothing (Hyprland only turns the screen off)
    sudo install -Dm644 "$SCRIPT_DIR/system/logind-lid.conf" /etc/systemd/logind.conf.d/lid.conf

    # Memory, as in Omarchy: zram the size of RAM, reclaim tuned for it, and systemd-oomd killing
    # the worst app (app.slice and tmux panes, see systemd-dropins) before the kernel OOM killer
    sudo rm -f /etc/systemd/system/user@.service.d/oomd.conf
    sudo install -Dm644 "$SCRIPT_DIR/system/zram-generator.conf" /etc/systemd/zram-generator.conf
    sudo install -Dm644 "$SCRIPT_DIR/system/sysctl-memory.conf" /etc/sysctl.d/99-jmpd-memory.conf
    sudo install -Dm644 "$SCRIPT_DIR/system/oomd.conf" /etc/systemd/oomd.conf.d/10-jmpd.conf
    sudo sysctl -q -p /etc/sysctl.d/99-jmpd-memory.conf
    sudo systemctl daemon-reload
    sudo systemctl enable systemd-oomd.service
    sudo systemctl restart systemd-oomd.service
    # Resizing zram swaps it off first, faulting every stored page back in: only while it's empty
    if [[ $(awk '$1 == "/dev/zram0" {print $4}' /proc/swaps) == 0 ]]; then
        sudo systemctl restart dev-zram0.swap
    fi

    # A laptop must not wait for the network to boot: docker pulls in network-online.target,
    # graphical.target waits for it, and uwsm won't start Hyprland until graphical.target is up
    sudo rm -rf /etc/systemd/system/systemd-networkd-wait-online.service.d
    sudo systemctl mask systemd-networkd-wait-online.service

    # Firewall: block incoming, allow outgoing (Omarchy's default)
    if sudo ufw status | grep -q '^Status: active'; then
        skip "ufw already active"
    else
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw --force enable
        sudo systemctl enable ufw.service
        ok "ufw enabled"
    fi
}

# NVIDIA is the only GPU (the RTX 3090 desktop). The laptop's NVIDIA sits next to the AMD iGPU
# that drives its panel, so this is false there.
nvidia_only() {
    local d vendors=""
    for d in /sys/bus/pci/devices/*; do
        [[ $(<"$d/class") == 0x03* ]] && vendors+="$(<"$d/vendor") "
    done
    [[ -n "$vendors" && -z "${vendors//0x10de /}" ]]
}

# 1b. NVIDIA desktop: driver, early KMS, and the Samsung TV's EDID fix
setup_nvidia_desktop() {
    info "Setting up NVIDIA desktop..."
    if ! nvidia_only; then
        skip "NVIDIA is not the only GPU"
        return 0
    fi

    # Open kernel modules (Turing and newer), built by DKMS for the stock kernel
    pkg_ensure linux-headers nvidia-open-dkms nvidia-utils egl-wayland libva-nvidia-driver

    # The TV's own EDID makes the link drop at 4K@60 (HDMI 2.0 limit): a patched copy replaces it,
    # with deep color and FRL off. drm is built into the kernel, so this goes on the cmdline.
    # Lenovo's HDMI audio as its own sink, next to the TV's (see the file)
    install_file "$SCRIPT_DIR/pipewire/10-nvidia-hdmi-lenovo.conf" \
        "$HOME/.config/pipewire/pipewire.conf.d/10-nvidia-hdmi-lenovo.conf"

    # Rebuild the initramfs/UKIs only if one of these changed
    local rebuild=0 src dest
    while read -r src dest; do
        cmp -s "$SCRIPT_DIR/$src" "$dest" && continue
        sudo install -Dm644 "$SCRIPT_DIR/$src" "$dest"
        ok "Installed: $dest"
        rebuild=1
    done <<EOF
system/edid/samsung_patched.bin /usr/lib/firmware/edid/samsung_patched.bin
system/nvidia-modprobe.conf /etc/modprobe.d/nvidia.conf
system/nvidia-mkinitcpio.conf /etc/mkinitcpio.conf.d/nvidia.conf
EOF

    # UKIs take the cmdline from /etc/kernel/cmdline if it exists, else /etc/cmdline.d/*.conf
    local params
    params="$(<"$SCRIPT_DIR/system/nvidia-cmdline.conf")"
    if [[ -f /etc/kernel/cmdline ]]; then
        if ! grep -q 'drm.edid_firmware=' /etc/kernel/cmdline; then
            sudo sed -i "s#\$# $params#" /etc/kernel/cmdline
            ok "Added to /etc/kernel/cmdline: $params"
            rebuild=1
        fi
    elif ! cmp -s "$SCRIPT_DIR/system/nvidia-cmdline.conf" /etc/cmdline.d/nvidia.conf; then
        sudo install -Dm644 "$SCRIPT_DIR/system/nvidia-cmdline.conf" /etc/cmdline.d/nvidia.conf
        ok "Installed: /etc/cmdline.d/nvidia.conf"
        rebuild=1
    fi
    if ! grep -qs '^default_uki' /etc/mkinitcpio.d/linux.preset; then
        warn "Not booting UKIs: add to the bootloader's kernel cmdline by hand: $params"
    fi

    if (( rebuild )); then
        sudo mkinitcpio -P
    else
        skip "initramfs already up to date"
    fi
}

# 1c. Steam. It needs a 32-bit Vulkan driver: install the lib32 twins of the GPU drivers present,
# or pacman picks a provider on its own (the GPU drivers come first, from 1b or the base install)
setup_steam() {
    info "Setting up Steam..."
    local pkgs=() drv
    for drv in nvidia-utils vulkan-radeon vulkan-intel; do
        pacman -Qq "$drv" &>/dev/null && pkgs+=("lib32-$drv")
    done
    pkg_ensure "${pkgs[@]}" steam
}

# 2. Set zsh as default shell
setup_default_shell() {
    info "Setting up default shell..."
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"

    if [[ "$current_shell" == *"/zsh" ]]; then
        skip "zsh is already the default shell"
        return 0
    fi

    info "Changing default shell to zsh (will prompt for password)"
    chsh -s "$(which zsh)"
    ok "Default shell changed to zsh — log out and back in for it to take effect"
}

# 3. Oh My Zsh
setup_oh_my_zsh() {
    info "Setting up Oh My Zsh..."
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        skip "Oh My Zsh already installed"
        return 0
    fi

    info "Installing Oh My Zsh (unattended)"
    # --unattended prevents the installer from launching zsh and stalling the script.
    # --keep-zshrc leaves any existing .zshrc alone — we manage it ourselves.
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended --keep-zshrc
    ok "Oh My Zsh installed"
}

# 4. OMZ plugins
setup_zsh_plugins() {
    info "Setting up zsh plugins..."
    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    git_clone_if_missing \
        "https://github.com/zsh-users/zsh-autosuggestions" \
        "$custom/plugins/zsh-autosuggestions"

    git_clone_if_missing \
        "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
        "$custom/plugins/zsh-syntax-highlighting"
}

# 5. Powerlevel10k
setup_powerlevel10k() {
    info "Setting up Powerlevel10k..."
    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    git_clone_if_missing \
        "https://github.com/romkatv/powerlevel10k.git" \
        "$custom/themes/powerlevel10k" \
        1
}

# 6. nvm + Node.js 24
setup_nvm() {
    info "Setting up nvm..."
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        skip "nvm already installed at $NVM_DIR"
    else
        info "Installing nvm via official install script"
        # The installer exits if NVM_DIR is set but the directory doesn't exist yet.
        mkdir -p "$NVM_DIR"
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
        ok "nvm installed"
    fi

    # Source nvm so we can use it in this session
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

    if ! command -v nvm >/dev/null 2>&1; then
        warn "nvm function not available — skipping Node.js install"
        return 0
    fi

    if nvm ls --no-colors 24 >/dev/null 2>&1; then
        skip "Node.js 24 already installed"
    else
        info "Installing Node.js 24 via nvm"
        nvm install 24
        nvm alias default 24
        ok "Node.js installed: $(node --version)"
    fi
}

# 7. Bun
setup_bun() {
    info "Setting up bun..."
    export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"

    if [[ -x "$BUN_INSTALL/bin/bun" ]]; then
        skip "bun already installed: $("$BUN_INSTALL/bin/bun" --version)"
        return 0
    fi

    info "Installing bun via official installer"
    curl -fsSL https://bun.sh/install | bash
    ok "bun installed"
}

# 8. Python via pyenv (build deps come from base-devel and the default Arch libs)
setup_python() {
    info "Setting up Python..."
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    eval "$(pyenv init -)" 2>/dev/null || true

    if pyenv versions --bare 2>/dev/null | grep -q '^3\.'; then
        skip "Python 3 already installed via pyenv"
    else
        local py_version
        py_version="$(pyenv install --list | grep -E '^\s+3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')"
        info "Installing Python $py_version via pyenv"
        pyenv install "$py_version"
        pyenv global "$py_version"
        ok "Python $py_version installed and set as global"
    fi
}

# 9. Docker service and group
setup_docker() {
    info "Setting up Docker..."
    sudo systemctl enable --now docker.service

    if groups "$USER" | grep -qw docker; then
        skip "User $USER already in docker group"
    else
        info "Adding $USER to docker group"
        sudo usermod -aG docker "$USER"
        ok "Added $USER to docker group — log out and back in for it to take effect"
    fi
}

# 10. Kitty config (kitty.conf includes current-theme.conf, so install both)
setup_kitty() {
    info "Setting up kitty config..."
    install_file "$SCRIPT_DIR/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    install_file "$SCRIPT_DIR/kitty-current-theme.conf" "$HOME/.config/kitty/current-theme.conf"
}

# 11. Neovim config
setup_neovim() {
    info "Setting up Neovim config..."
    # Config is kickstart.nvim plus local edits (catppuccin, LSPs, neo-tree, agentic opts), kept in nvim/.
    install_dir "$SCRIPT_DIR/nvim" "$HOME/.config/nvim"
}

# 11b. Hyprland config (macOS-style keys, paired with keyd-default.conf)
setup_hyprland() {
    info "Setting up Hyprland config..."
    install_file "$SCRIPT_DIR/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
    install_file "$SCRIPT_DIR/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"

    # Omarchy 3.8 look: top bar, lockscreen and screensaver
    install_file "$SCRIPT_DIR/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
    install_file "$SCRIPT_DIR/hypr/screensaver.txt" "$HOME/.config/hypr/screensaver.txt"
    # Screensaver animation tool (bin/jmpd-screensaver)
    have tte || uv tool install terminaltexteffects
    install_file "$SCRIPT_DIR/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
    install_file "$SCRIPT_DIR/waybar/style.css" "$HOME/.config/waybar/style.css"
    install_file "$SCRIPT_DIR/wofi/config" "$HOME/.config/wofi/config"
    install_file "$SCRIPT_DIR/swayosd/config.toml" "$HOME/.config/swayosd/config.toml"

    # Colors and wallpaper come from an Omarchy theme: jmpd-theme renders these
    # templates into the bar, lockscreen, launcher, borders, kitty and hyprpaper configs
    install_dir "$SCRIPT_DIR/themes/templates" "$HOME/.local/share/jmpd-theme/templates"
    [[ -f "$HOME/.config/jmpd-theme/current" ]] || "$SCRIPT_DIR/bin/jmpd-theme" set catppuccin

    # Bar, wallpaper and idle-lock run as user services inside the uwsm session
    systemctl --user enable waybar.service hyprpaper.service hypridle.service

    # SDDM is the login screen, with Omarchy's theme. The greeter runs on a minimal
    # Hyprland instead of Xorg, which picked the NVIDIA dGPU while the panel is on the AMD iGPU.
    sudo install -Dm644 -t /usr/share/sddm/themes/omarchy "$SCRIPT_DIR"/sddm/omarchy/*
    sudo install -Dm644 "$SCRIPT_DIR/sddm/hyprland.lua" /usr/share/sddm/hyprland.lua
    sudo install -Dm644 -t /etc/sddm.conf.d "$SCRIPT_DIR/sddm/10-theme.conf" "$SCRIPT_DIR/sddm/10-wayland.conf"
    sudo rm -f /etc/X11/xorg.conf.d/10-amdgpu-primary.conf
    sudo systemctl enable sddm.service
    # The theme has only a password box, so preselect this user and the uwsm session
    if ! sudo test -f /var/lib/sddm/state.conf; then
        printf '[Last]\nUser=%s\nSession=/usr/share/wayland-sessions/hyprland-uwsm.desktop\n' "$USER" \
            | sudo install -Dm644 -o sddm -g sddm /dev/stdin /var/lib/sddm/state.conf
        ok "SDDM preselects $USER"
    fi
}

# 12. Claude Code
setup_claude() {
    info "Setting up Claude Code..."
    if have claude; then
        skip "Claude Code already installed: $(claude --version 2>/dev/null | head -1)"
        return 0
    fi
    curl -fsSL https://claude.ai/install.sh | bash
    ok "Claude Code installed"
}

# 12b. Codex CLI (official installer, into ~/.local/bin like Claude Code)
setup_codex() {
    info "Setting up Codex..."
    if have codex; then
        skip "Codex already installed: $(codex --version 2>/dev/null | head -1)"
        return 0
    fi
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
    ok "Codex installed (run: codex login)"
}


# 12c. Agent skills: one copy in agents/skills, linked for both Claude Code and Codex
setup_agent_skills() {
    info "Linking agent skills..."
    local dir skill
    for dir in "$HOME/.claude/skills" "$HOME/.codex/skills"; do
        mkdir -p "$dir"
        for skill in "$SCRIPT_DIR"/agents/skills/*/; do
            ln -sfn "${skill%/}" "$dir/$(basename "$skill")"
        done
    done
    ok "Agent skills linked"
}


# 13. AUR apps (the rest of the apps are in the package list above)
setup_aur_apps() {
    info "Setting up AUR applications..."
    if ! have yay; then
        err "yay not found — install it first (https://github.com/Jguer/yay)"
        return 1
    fi

    local apps=(
        brave-bin
        slack-desktop
        lastpass-cli
    )

    for app in "${apps[@]}"; do
        aur_ensure "$app"
    done
}

# 14. Default applications / mime associations
setup_defaults() {
    info "Setting up default applications..."

    if have xdg-mime; then
        local current
        current="$(xdg-mime query default application/pdf || true)"
        if [[ "$current" == "org.gnome.Evince.desktop" ]]; then
            skip "Evince already default PDF viewer"
        else
            xdg-mime default org.gnome.Evince.desktop application/pdf
            ok "Evince set as default PDF viewer"
        fi
    fi
    if have xdg-settings && [[ "$(xdg-settings get default-web-browser)" != "brave-browser.desktop" ]]; then
        xdg-settings set default-web-browser brave-browser.desktop
        ok "Brave set as default browser"
    fi
    if have xdg-mime; then xdg-mime default brave-browser.desktop x-scheme-handler/mailto; fi
}

# 15. keyd — low-level key remapper (macOS-style Cmd keybinds via Left Alt)
setup_keyd() {
    info "Setting up keyd..."
    # Config lives in /etc (needs sudo, so install_file's user-space cp won't do).
    sudo mkdir -p /etc/keyd
    if [[ -f /etc/keyd/default.conf ]] && cmp -s "$SCRIPT_DIR/keyd-default.conf" /etc/keyd/default.conf; then
        skip "keyd config already up to date: /etc/keyd/default.conf"
    else
        if [[ -f /etc/keyd/default.conf ]]; then
            local backup="/etc/keyd/default.conf.bak.$(date +%Y%m%d-%H%M%S)"
            warn "Backing up existing keyd config to: $backup"
            sudo cp /etc/keyd/default.conf "$backup"
        fi
        sudo cp "$SCRIPT_DIR/keyd-default.conf" /etc/keyd/default.conf
        ok "Installed: /etc/keyd/default.conf"
    fi

    sudo systemctl enable --now keyd
    sudo keyd reload 2>/dev/null || true
    ok "keyd service enabled and reloaded"
}

# 16. User configs
setup_configs() {
    info "Setting up user configs..."
    # Only copy files that exist in the repo. Add more as you commit them.
    [[ -f "$SCRIPT_DIR/zshrc"     ]] && install_file "$SCRIPT_DIR/zshrc"     "$HOME/.zshrc"
    [[ -f "$SCRIPT_DIR/p10k.zsh"  ]] && install_file "$SCRIPT_DIR/p10k.zsh"  "$HOME/.p10k.zsh"
    [[ -f "$SCRIPT_DIR/gitconfig" ]] && install_file "$SCRIPT_DIR/gitconfig" "$HOME/.gitconfig"
    [[ -f "$SCRIPT_DIR/tmux.conf" ]] && install_file "$SCRIPT_DIR/tmux.conf" "$HOME/.tmux.conf"

    # WirePlumber rules: Bluetooth A2DP auto-connect, KEF LSX II never suspended
    local f
    for f in "$SCRIPT_DIR"/wireplumber/*.conf; do
        install_file "$f" "$HOME/.config/wireplumber/wireplumber.conf.d/$(basename "$f")"
    done
}

# 17. Personal scripts, user services, desktop entries, udev rules
setup_scripts() {
    info "Setting up personal scripts and services..."
    local f
    for f in "$SCRIPT_DIR"/bin/*; do
        install_file "$f" "$HOME/.local/bin/$(basename "$f")"
        chmod +x "$HOME/.local/bin/$(basename "$f")"
    done

    # Window buttons on the left (close, maximize); GTK settings.ini comes from jmpd-theme
    gsettings set org.gnome.desktop.wm.preferences button-layout 'close,maximize:'

    for f in "$SCRIPT_DIR"/applications/icons/*.png; do
        install_file "$f" "$HOME/.local/share/icons/hicolor/512x512/apps/$(basename "$f")"
    done
    for f in "$SCRIPT_DIR"/applications/*.desktop; do
        install_file "$f" "$HOME/.local/share/applications/$(basename "$f")"
    done

    for f in "$SCRIPT_DIR"/systemd/*; do
        install_file "$f" "$HOME/.config/systemd/user/$(basename "$f")"
    done
    # Drop-ins for packaged user units (e.g. waybar stops with the session)
    for f in "$SCRIPT_DIR"/systemd-dropins/*/*.conf; do
        install_file "$f" "$HOME/.config/systemd/user/$(basename "$(dirname "$f")")/$(basename "$f")"
    done
    systemctl --user daemon-reload
    systemctl --user enable --now ac-no-sleep.service cursor-update.timer
    # Volume/brightness popups and clipboard history, inside the Hyprland session
    systemctl --user enable swayosd.service cliphist.service
    # Memory pressure warnings (notification + waybar), see bin/jmpd-mem-pressure
    systemctl --user enable jmpd-mem-pressure.service

    for f in "$SCRIPT_DIR"/udev/*.rules; do
        if [[ -f "/etc/udev/rules.d/$(basename "$f")" ]] && cmp -s "$f" "/etc/udev/rules.d/$(basename "$f")"; then
            skip "Already up to date: /etc/udev/rules.d/$(basename "$f")"
        else
            sudo cp "$f" /etc/udev/rules.d/
            ok "Installed: /etc/udev/rules.d/$(basename "$f")"
        fi
    done
    sudo udevadm control --reload-rules
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    info "Starting local setup..."
    setup_packages
    setup_nvidia_desktop
    setup_steam
    setup_default_shell
    setup_oh_my_zsh
    setup_zsh_plugins
    setup_powerlevel10k
    setup_nvm
    setup_bun
    setup_python
    setup_docker
    setup_kitty
    setup_neovim
    setup_hyprland
    setup_claude
    setup_codex
    setup_agent_skills
    setup_aur_apps
    setup_defaults
    setup_keyd
    setup_configs
    setup_scripts
    ok "Local setup complete."
}

main "$@"
