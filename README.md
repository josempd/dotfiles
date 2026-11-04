# dotfiles

My Arch Linux + Hyprland desktop: one RTX 3090, a Samsung 4K TV and a 32:9 Lenovo ultrawide. The look is [Omarchy](https://github.com/omacom/omarchy) rebuilt by hand on plain Arch, without installing Omarchy.

**Don't run `jmpd.sh` on your machine.** It converges *this* desktop: it installs NVIDIA drivers, edits `/etc/kernel/cmdline`, loads a patched EDID for my TV and enables a firewall. Read it, take the pieces you want.

## Worth taking

- **[`check.sh`](check.sh)**, a pre-commit hook that keeps the repo lean: every file is installed, every script is used, no guards, no drift between the repo and the live system. The rules are in the [skill](agents/skills/arch-desktop/SKILL.md#mvi-rules-minimum-viable-interface).
- **[`jmpd-theme`](bin/jmpd-theme)** applies any Omarchy theme without Omarchy: it renders [`themes/templates/`](themes/templates) into waybar, Hyprland, hyprlock, kitty, wofi, mako, swayosd, btop, GTK and Qt.
- **[`keyd-default.conf`](keyd-default.conf)**, a macOS layout on a PC keyboard: Cmd shortcuts in apps, Option for windows, Hyprland bindings that never collide with apps.
- **NVIDIA HDMI fixes**: a patched EDID plus `nvidia_modeset` params that keep a TV's 4K@60 link up ([`system/`](system)), and audio on both displays at once ([`pipewire/`](pipewire), [`wireplumber/`](wireplumber)).
- **[`jmpd-agents`](bin/jmpd-agents)**, a waybar icon and GTK panel for coding agent limits and token use, built on Omarchy's collectors ([`vendor/`](vendor/omarchy-agents)).
- **[The arch-desktop skill](agents/skills/arch-desktop/SKILL.md)**: how the whole desktop fits together, written for coding agents (Claude Code, Codex) that change it.

## Install

On a fresh Arch install, as a sudo user:

```bash
git clone https://github.com/josempd/dotfiles.git ~/code/dotfiles
~/code/dotfiles/jmpd.sh
```

`jmpd.sh` is safe to re-run. `./check.sh` checks the rules and drift against the live system. Laptop support lives on the `laptop` branch.

## Credits

[Omarchy](https://github.com/omacom/omarchy) for the look, the SDDM theme, the themes and the agent collectors; [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) for the Neovim base. Both MIT.

## License

[MIT](LICENSE)
