# Every terminal is tmux (reattach a detached session, else a new one); before p10k, which grabs the tty. NO_TMUX=1 skips
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && [[ -z "$NO_TMUX" ]]; then
  __tmux_free=$(tmux list-sessions -F '#{session_attached} #{session_name}' 2>/dev/null | awk '$1=="0"{print $2; exit}')
  if [[ -n "$__tmux_free" ]]; then
    exec tmux attach -t "$__tmux_free"
  fi
  exec tmux new-session
fi

# p10k instant prompt: anything that reads the console goes above this
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="$HOME/.local/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting kubectl kubectx)
source $ZSH/oh-my-zsh.sh

export EDITOR='nvim'

eval "$(mise activate zsh)"

source ~/.p10k.zsh

# Zed editor: Arch's package installs the command as zeditor
alias zed=zeditor

# No XON/XOFF, so Ctrl+S (keyd's Cmd+S) reaches apps; /dev/tty because instant prompt may hold stdin
stty -ixon </dev/tty 2>/dev/null

# Last 3 commands with their output in ~/.cache/cmdcap/1..3, which tmux's Alt+1/2/3 copy
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

# Machine-local config and secrets, untracked
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
