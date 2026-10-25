# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# === Omarchy (2026-10-25) ===
# No oh-my-zsh: theme + plugins come from pacman (zsh-autosuggestions,
# zsh-syntax-highlighting, zsh-completions) and a git clone of powerlevel10k
# in ~/.local/share/powerlevel10k (not packaged in Arch repos).
# Omarchy's bash defaults are mirrored here: its aliases file is zsh-compatible,
# the tool inits (mise, zoxide, fzf) are re-done with their zsh variants.
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap
: "${OMARCHY_PATH:=/usr/share/omarchy}"
export BROWSER="${BROWSER:-omarchy-launch-browser}"
export BAT_THEME=ansi
export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
source "$OMARCHY_PATH/default/bash/aliases"   # eza ls, zoxide cd, t/h/n/cx, g/gcm…

command -v mise   >/dev/null && eval "$(mise activate zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# Completion (zsh-completions installs into the default fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu select

# fzf: Ctrl+R history, Ctrl+T files, Alt+C cd
command -v fzf >/dev/null && source <(fzf --zsh)

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Esc Esc: prefix the current (or previous) command with sudo — replaces omz's sudo plugin
sudo-command-line() {
  [[ -z $BUFFER ]] && BUFFER=$(fc -ln -1)
  if [[ $BUFFER == sudo\ * ]]; then BUFFER=${BUFFER#sudo }; else BUFFER="sudo $BUFFER"; fi
  CURSOR=${#BUFFER}
}
zle -N sudo-command-line
bindkey '\e\e' sudo-command-line

source ~/.local/share/powerlevel10k/powerlevel10k.zsh-theme

HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups


# To customize prompt, run `p10k configure` or edit ~/.dotfiles/zsh/.p10k.zsh.
[[ ! -f ~/.dotfiles/zsh/.p10k.zsh ]] || source ~/.dotfiles/zsh/.p10k.zsh

# Disable flow control so custom tmux key bindings work
# Only disable flow control if we’re in a real terminal
if [[ -t 0 ]]; then
  stty -ixon
fi

bindkey -r '^S'

# Claude Code with rust-vanilla-sdlc orchestrator (latest installed version)
alias sohoc='claude --append-system-prompt "$(cat "$(ls -1d ~/.claude/plugins/cache/rust-vanilla-sdlc/rust-vanilla-sdlc/*/prompts/orchestrator.md | sort -V | tail -1)")"'

# === sccache (added 2026-05-06) ===
# Shared compilation cache for rust builds across worktrees/projects.
# Backed by ~/.cache/sccache, capped at 20G with LRU eviction.
# Note: cargo invocations also pick this up via ~/.cargo/config.toml
# (rustc-wrapper = "sccache") regardless of shell.
# Guarded (2026-10-25): a machine without sccache would break every cargo build.
if command -v sccache >/dev/null; then
  export RUSTC_WRAPPER=sccache
  export SCCACHE_CACHE_SIZE=20G
  export SCCACHE_DIR=$HOME/.cache/sccache
fi

# === worktree hygiene (added 2026-05-06) ===
alias pwt='prune-worktrees'
alias pwt-go='prune-worktrees --execute'

# === Nexus cargo token for Dockerised builds (added 2026-07-12) ===
# The wellness-service integration harness (bin/integration_tests) runs cargo
# inside a Docker container that does NOT inherit ~/.cargo/credentials.toml, so
# it 401s fetching apron-* unless these are in the launch shell's environment.
# Derived from the existing credential at shell start — no secret stored here;
# self-heals if the token rotates. CARGO_REGISTRIES_NEXUS_GROUP_TOKEN is the one
# cargo consumes (registry is named nexus-group).
if [ -f "$HOME/.cargo/credentials.toml" ]; then
  export CARGO_REGISTRIES_NEXUS_GROUP_TOKEN="$(awk '/^\[registries\.nexus-group\]/{f=1;next} /^\[/{f=0} f&&/^token/{sub(/^token *= *"/,"");sub(/" *$/,"");print;exit}' "$HOME/.cargo/credentials.toml")"
  export CARGO_REGISTRIES_NEXUS_TOKEN="$CARGO_REGISTRIES_NEXUS_GROUP_TOKEN"
fi

# === Soho Wellness SDLC plugin launcher (added 2026-07-12) ===
# Runs Claude in the client repo with the LOCAL dev plugin checkout
# (feature/hardening-stack = hardening + Soho adaptation), the stale marketplace
# copy disabled, and the orchestrator system prompt appended. Extra args pass
# through, e.g.  soho-sdlc --dangerously-skip-permissions  for a hands-off run.
soho-sdlc() {
  local plugdir=/home/rory/tools/sdlc-agent-kit/rust-vanilla-sdlc
  local clientrepo=/home/rory/Tangent/soho-wellness/internal
  local want=feature/hardening-stack
  local br; br=$(git -C "$plugdir" branch --show-current 2>/dev/null)
  if [[ "$br" != "$want" ]]; then
    if [[ -z "$(git -C "$plugdir" status --porcelain 2>/dev/null)" ]]; then
      git -C "$plugdir" switch "$want" >/dev/null 2>&1 || { echo "soho-sdlc: cannot switch plugin to $want"; return 1; }
    else
      echo "soho-sdlc: ⚠ plugin checkout on '$br' with local changes — loading as-is, NOT $want."
    fi
  fi
  echo "soho-sdlc: plugin @ $(git -C "$plugdir" branch --show-current) ($(git -C "$plugdir" rev-parse --short HEAD 2>/dev/null)) → $clientrepo"
  ( cd "$clientrepo" && claude \
      --plugin-dir "$plugdir" \
      --settings '{"enabledPlugins": {"rust-vanilla-sdlc@rust-vanilla-sdlc": false}}' \
      --append-system-prompt-file "$plugdir/prompts/orchestrator.md" \
      "$@" )
}

# Must be sourced last so it sees every widget defined above
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
