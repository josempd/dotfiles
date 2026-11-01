# dotfiles

Arch Linux + Hyprland on an RTX 3090 desktop. `jmpd.sh` installs every package and copies every file in this repo to its place; it is safe to re-run.

```bash
git clone https://github.com/josempd/dotfiles.git ~/code/dotfiles
~/code/dotfiles/jmpd.sh
```

Needs a fresh Arch install with a sudo user (not root). `./check.sh` checks the repo rules and drift against the live system.

How the desktop fits together, and the rules for changing it: [`agents/skills/arch-desktop/SKILL.md`](agents/skills/arch-desktop/SKILL.md). Laptop support lives on the `laptop` branch.
