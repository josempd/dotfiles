#!/usr/bin/env bash
# Converges this Arch + Hyprland desktop to the repo: packages, files, services. Safe to re-run.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANGED=()

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  +\033[0m %s\n' "$*"; }

[[ $EUID -ne 0 ]] || { echo "Run as your user: it asks for sudo when needed" >&2; exit 1; }

# Copies a tracked file, or every tracked file under a dir, to DEST when it differs (sudo outside $HOME)
put() {
    local src=$1 dest=$2 f to sudo=()
    [[ $dest == "$HOME"/* ]] || sudo=(sudo)
    for f in $(git -C "$DIR" ls-files "$src"); do
        to="$dest${f#"$src"}"
        "${sudo[@]}" cmp -s "$DIR/$f" "$to" && continue
        "${sudo[@]}" diff -u "$to" "$DIR/$f" 2>/dev/null || true
        "${sudo[@]}" install -Dm"$(stat -c %a "$DIR/$f")" "$DIR/$f" "$to"
        CHANGED+=("$to")
        ok "$to"
    done
}

# Did a put in this run change a path matching the glob?
changed() {
    local p
    for p in "${CHANGED[@]}"; do
        # shellcheck disable=SC2053
        [[ $p == $1 ]] && return 0
    done
    return 1
}

clone() { [[ -d $2 ]] || git clone -q --depth=1 "$1" "$2"; }

PACKAGES=(
    # Base and shell
    zsh git curl ca-certificates base-devel unzip xdg-utils shellcheck
    ripgrep fd fzf jq lazygit wl-clipboard tmux
    kitty neovim bluez bluez-utils keyd openssh github-cli
    btop man-db less plocate pacman-contrib

    # Hyprland session, audio, lock/idle, bar, launcher, screenshots, fonts
    hyprland uwsm sddm xdg-desktop-portal-hyprland polkit-kde-agent qt6-wayland qt6ct zram-generator
    python-gobject ffmpeg
    wireplumber pipewire-pulse pipewire-alsa pipewire-jack rtkit alsa-utils
    hyprlock hypridle hyprpaper waybar wofi hyprsunset satty grim slurp
    impala bluetui wiremix mako libnotify cliphist swayosd xorg-xrandr
    playerctl power-profiles-daemon ufw
    gnome-keyring xdg-desktop-portal-gtk
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk noto-fonts-extra

    # NVIDIA (open modules via DKMS), Steam with its 32-bit driver, CUDA for llama.cpp
    linux-headers nvidia-open-dkms nvidia-utils egl-wayland libva-nvidia-driver
    lib32-nvidia-utils steam cuda cmake

    # Apps
    nautilus sushi mpv papers obsidian telegram-desktop discord zed spotify-launcher

    # Runtimes (node, python, pnpm, bun, pi come from mise)
    mise uv python

    # Containers, Kubernetes, cloud, VPN
    docker docker-buildx docker-compose
    kubectl kubectx k9s helm kubeseal argocd
    aws-cli-v2 terraform sshpass openfortivpn tailscale

    # AUR
    brave-bin yaru-icon-theme hyprland-preview-share-picker-git slack-desktop cursor-bin
)

FILES=(
    "zshrc $HOME/.zshrc"
    "p10k.zsh $HOME/.p10k.zsh"
    "gitconfig $HOME/.gitconfig"
    "tmux.conf $HOME/.tmux.conf"
    "kitty.conf $HOME/.config/kitty/kitty.conf"
    "brave-flags.conf $HOME/.config/brave-flags.conf"
    "cursor-flags.conf $HOME/.config/cursor-flags.conf"
    "nvim $HOME/.config/nvim"
    "mise/global.toml $HOME/.config/mise/config.toml"
    "uv/uv.toml $HOME/.config/uv/uv.toml"
    "uwsm-env $HOME/.config/uwsm/env"
    "hypr $HOME/.config/hypr"
    "waybar $HOME/.config/waybar"
    "wofi $HOME/.config/wofi"
    "swayosd $HOME/.config/swayosd"
    "share-picker $HOME/.config/hyprland-preview-share-picker"
    "pipewire/10-nvidia-hdmi-lenovo.conf $HOME/.config/pipewire/pipewire.conf.d/10-nvidia-hdmi-lenovo.conf"
    "pipewire/nvidia-hdmi-tv.profile-set.conf $HOME/.config/alsa-card-profile/mixer/profile-sets/nvidia-hdmi-tv.conf"
    "wireplumber $HOME/.config/wireplumber/wireplumber.conf.d"
    "agents-local.json $HOME/.config/omarchy/agents/local.json"
    "vendor/omarchy-agents $HOME/.local/share/jmpd-agents"
    "themes/templates $HOME/.local/share/jmpd-theme/templates"
    "bin $HOME/.local/bin"
    "applications $HOME/.local/share/applications"
    "icons $HOME/.local/share/icons/hicolor/512x512/apps"
    "systemd $HOME/.config/systemd/user"
    "systemd-dropins $HOME/.config/systemd/user"
    "keyd-default.conf /etc/keyd/default.conf"
    "system/zram-generator.conf /etc/systemd/zram-generator.conf"
    "system/sysctl-memory.conf /etc/sysctl.d/99-jmpd-memory.conf"
    "system/oomd.conf /etc/systemd/oomd.conf.d/10-jmpd.conf"
    "system/nvidia-modprobe.conf /etc/modprobe.d/nvidia.conf"
    "system/nvidia-mkinitcpio.conf /etc/mkinitcpio.conf.d/nvidia.conf"
    "system/edid/samsung_patched.bin /usr/lib/firmware/edid/samsung_patched.bin"
    "sddm/omarchy /usr/share/sddm/themes/omarchy"
    "sddm/hyprland.lua /usr/share/sddm/hyprland.lua"
    "sddm/conf.d /etc/sddm.conf.d"
)

setup_packages() {
    info "Packages"
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    fi
    if ! pacman -Qq yay-bin &>/dev/null; then
        sudo pacman -S --needed --noconfirm git base-devel
        local tmp
        tmp="$(mktemp -d)"
        git clone -q --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp"
        (cd "$tmp" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi
    yay -Syu --noconfirm
    local missing
    missing=$(pacman -T "${PACKAGES[@]}" || true)
    # shellcheck disable=SC2086
    if [[ -n $missing ]]; then yay -S --noconfirm $missing; fi
}

setup_files() {
    info "Files"
    local entry p
    for entry in "${FILES[@]}"; do
        # shellcheck disable=SC2086
        put $entry
    done
    # The patched EDID and NVIDIA params on the kernel cmdline keep the TV's 4K@60 link up
    for p in $(<"$DIR/system/nvidia-cmdline.conf"); do
        [[ " $(</etc/kernel/cmdline) " == *" $p "* ]] && continue
        sudo sed -i "s#\$# $p#" /etc/kernel/cmdline
        CHANGED+=(/etc/kernel/cmdline)
        ok "/etc/kernel/cmdline: $p"
    done
}

setup_system() {
    info "System"
    if changed '/etc/kernel/cmdline' || changed '/etc/modprobe.d/*' || changed '/etc/mkinitcpio.conf.d/*' \
        || changed '/usr/lib/firmware/*'; then
        sudo mkinitcpio -P
    fi
    if changed '/etc/sysctl.d/*'; then sudo sysctl -q -p /etc/sysctl.d/99-jmpd-memory.conf; fi
    if changed '/etc/systemd/*'; then sudo systemctl daemon-reload; fi
    if changed '/etc/systemd/oomd.conf.d/*'; then sudo systemctl restart systemd-oomd.service; fi
    # Resizing zram swaps it off first, faulting every stored page back in: only while it's empty
    if changed '/etc/systemd/zram-generator.conf' && [[ $(awk '$1 == "/dev/zram0" {print $4}' /proc/swaps) == 0 ]]; then
        sudo systemctl restart dev-zram0.swap
    fi
    if changed '/etc/keyd/*'; then sudo keyd reload; fi
    # Nothing waits for the network at boot: docker pulls in network-online.target, which held up uwsm
    sudo systemctl mask systemd-networkd-wait-online.service
    sudo systemctl enable --now bluetooth.service power-profiles-daemon.service paccache.timer \
        systemd-oomd.service docker.service keyd.service
    sudo systemctl enable sddm.service
    sudo usermod -aG docker "$USER"
    if ! sudo ufw status | grep -q '^Status: active'; then
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw --force enable
        sudo systemctl enable ufw.service
    fi
    # The SDDM theme has only a password box, so preselect this user and the uwsm session
    if ! sudo test -f /var/lib/sddm/state.conf; then
        printf '[Last]\nUser=%s\nSession=/usr/share/wayland-sessions/hyprland-uwsm.desktop\n' "$USER" \
            | sudo install -Dm644 -o sddm -g sddm /dev/stdin /var/lib/sddm/state.conf
    fi
}

setup_shell() {
    info "Shell"
    [[ $(getent passwd "$USER" | cut -d: -f7) == */zsh ]] || chsh -s /usr/bin/zsh
    if [[ ! -d $HOME/.oh-my-zsh ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            "" --unattended --keep-zshrc
    fi
    local custom=$HOME/.oh-my-zsh/custom
    clone https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions"
    clone https://github.com/zsh-users/zsh-syntax-highlighting "$custom/plugins/zsh-syntax-highlighting"
    clone https://github.com/romkatv/powerlevel10k "$custom/themes/powerlevel10k"
}

setup_tools() {
    info "Tools"
    mise install --yes
    uv tool install terminaltexteffects
    command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
    command -v codex >/dev/null || curl -fsSL https://chatgpt.com/codex/install.sh | sh
    ln -sfn ../../check.sh "$DIR/.git/hooks/pre-commit"
    # One copy of the skills in agents/skills, linked for Claude Code and Codex
    local dir skill
    for dir in "$HOME/.claude/skills" "$HOME/.codex/skills"; do
        mkdir -p "$dir"
        for skill in "$DIR"/agents/skills/*/; do
            ln -sfn "${skill%/}" "$dir/$(basename "$skill")"
        done
    done
}

# llama-server with CUDA at a pinned llama.cpp commit; move ref to upgrade. Models are fetched by hand.
setup_llama_server() {
    info "llama-server"
    local ref=4f37f519722aa3242eecb7649466b4a4a2d6d6da src=$HOME/llama.cpp
    [[ -d $src ]] || git clone -q https://github.com/ggml-org/llama.cpp "$src"
    if [[ $(git -C "$src" rev-parse HEAD) != "$ref" ]]; then
        git -C "$src" fetch -q origin
        git -C "$src" checkout -q "$ref"
        rm -rf "$src/build"
    fi
    if ! "$src/build/bin/llama-server" --version &>/dev/null; then
        cmake -S "$src" -B "$src/build" -DGGML_CUDA=ON -DCMAKE_CUDA_COMPILER=/opt/cuda/bin/nvcc
        cmake --build "$src/build" --config Release -j "$(nproc)" --target llama-server
    fi
}

setup_desktop() {
    info "Desktop"
    "$DIR/bin/jmpd-theme" reapply
    gsettings set org.gnome.desktop.wm.preferences button-layout 'close,maximize:'
    xdg-mime default org.gnome.Papers.desktop application/pdf
    xdg-mime default brave-browser.desktop x-scheme-handler/mailto
    xdg-settings set default-web-browser brave-browser.desktop
    systemctl --user daemon-reload
    systemctl --user enable waybar.service hyprpaper.service hypridle.service swayosd.service \
        cliphist.service jmpd-mem-pressure.service
}

setup_packages
setup_files
setup_system
setup_shell
setup_tools
setup_llama_server
setup_desktop
info "Done"
