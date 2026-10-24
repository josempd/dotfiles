# tmux auto-attach: keeps shells alive across a kitty crash. Must run BEFORE the
# p10k instant-prompt preamble — tmux needs the real terminal, which the preamble
# captures. Interactive shells only, and not when already inside tmux.
# Reattaches a detached session if one exists, else starts a new one
# (so a second kitty window gets its own session instead of mirroring).
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && command -v tmux &>/dev/null; then
  __tmux_free=$(tmux list-sessions -F '#{session_attached} #{session_name}' 2>/dev/null | awk '$1=="0"{print $2; exit}')
  if [[ -n "$__tmux_free" ]]; then
    tmux attach -t "$__tmux_free"
  else
    tmux new-session
  fi
  unset __tmux_free
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
export PATH="$HOME/.local/bin:/usr/local/go/bin:$HOME/go/bin:$PATH"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions zsh-syntax-highlighting kubectl kubectx)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

export EDITOR='nvim'

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# nvm
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null

# bun
export BUN_INSTALL="$HOME/.bun"
[[ -d "$BUN_INSTALL/bin" ]] && export PATH="$BUN_INSTALL/bin:$PATH"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Zed editor: Arch's package installs the command as zeditor
alias zed=zeditor

# Disable legacy XON/XOFF terminal flow control so Ctrl+S no longer "freezes"
# the terminal. Frees Ctrl+S for apps (and for keyd's Cmd+S -> Ctrl+S mapping).
# Target /dev/tty explicitly + silence errors: under p10k instant prompt, stdin
# isn't always a tty here, and a bare `stty` error counts as init console output
# (which triggers p10k's "console output during zsh initialization" warning).
stty -ixon </dev/tty 2>/dev/null

# ── Copy last command+output blocks to clipboard (Alt+1/2/3 via tmux) ─────────
# preexec records the command (verbatim) + where its output begins in the tmux
# scrollback; precmd captures that output with capture-pane into a 3-slot ring
# buffer (~/.cache/cmdcap/1..3, slot 1 = most recent). tmux binds Alt+1/2/3 to
# wl-copy the matching slot -- handy for pasting terminal context into Claude.
if [[ -n "$TMUX" ]]; then
  _CMDCAP_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cmdcap"
  mkdir -p "$_CMDCAP_DIR"

  _cmdcap_preexec() {
    _CMDCAP_CMD="$1"
    # absolute row (scrollback + on-screen) where this command's output begins
    _CMDCAP_START=$(( $(tmux display -p '#{history_size}') + $(tmux display -p '#{cursor_y}') ))
    _CMDCAP_ACTIVE=1
  }

  _cmdcap_precmd() {
    [[ -n "$_CMDCAP_ACTIVE" ]] || return   # skip bare Enter (no command ran)
    _CMDCAP_ACTIVE=
    local hs cy start end out
    hs=$(tmux display -p '#{history_size}')
    cy=$(tmux display -p '#{cursor_y}')
    start=$(( _CMDCAP_START - hs ))         # convert absolute -> visible-relative
    end=$(( cy - 1 ))                        # stop above the fresh prompt/cursor line
    (( end < start )) && end=$start
    # capture output, strip trailing spaces per line (capture-pane right-pads)
    out=$(tmux capture-pane -pJ -S "$start" -E "$end" 2>/dev/null | sed 's/[[:space:]]*$//')
    # rotate ring: 1->2->3 (drop old 3), then write newest to slot 1
    [[ -f "$_CMDCAP_DIR/2" ]] && mv -f "$_CMDCAP_DIR/2" "$_CMDCAP_DIR/3"
    [[ -f "$_CMDCAP_DIR/1" ]] && mv -f "$_CMDCAP_DIR/1" "$_CMDCAP_DIR/2"
    { print -r -- "> $_CMDCAP_CMD"; print -r -- "$out"; } > "$_CMDCAP_DIR/1"
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _cmdcap_preexec
  add-zsh-hook precmd  _cmdcap_precmd
fi

# ── worktrunk (git worktrees for parallel agents) ────────────────────────────
# `wt` shell function lets `wt switch` cd; wtclean drops merged worktrees plus stale git metadata.
if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
wtclean() { wt step prune --foreground "$@" && git worktree prune -v; }

# Machine-local config (work functions, secrets) — untracked, keep out of this repo.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
