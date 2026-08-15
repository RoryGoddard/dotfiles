# Migrated to a single systemd --user ssh-agent so systemd services (pr-reviewer,
# herdr) share the same passphrase-unlocked keys as interactive shells. See
# ~/.config/systemd/user/ssh-agent.service.d/override.conf,
# ~/.config/environment.d/10-ssh-agent.conf and ~/.zshenv. keychain's per-login
# /tmp agent was invisible to --user services, which re-prompted for the passphrase.
# eval "$(keychain --eval --quiet id_ed25519_github_tangent id_ed25519_gitlab_work id_ed25519)"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Rory: Added this to try get hyprland to load kitty
export PATH="$HOME/.local/kitty.app/bin:$PATH"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

export PATH="$HOME/.local/bin:$PATH"

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

plugins=(
  git
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
  fzf
  sudo
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

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

# History
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


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Disable flow control so custom tmux key bindings work
# Only disable flow control if we’re in a real terminal
if [[ -t 0 ]]; then
  stty -ixon
fi

bindkey -r '^S'


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

alias xdg-open='handlr open'

# Claude Code with rust-vanilla-sdlc orchestrator (latest installed version)
alias sohoc='claude --append-system-prompt "$(cat "$(ls -1d ~/.claude/plugins/cache/rust-vanilla-sdlc/rust-vanilla-sdlc/*/prompts/orchestrator.md | sort -V | tail -1)")"'

# To customize prompt, run `p10k configure` or edit ~/.dotfiles/zsh/.p10k.zsh.
[[ ! -f ~/.dotfiles/zsh/.p10k.zsh ]] || source ~/.dotfiles/zsh/.p10k.zsh

# === sccache (added 2026-05-06) ===
# Shared compilation cache for rust builds across worktrees/projects.
# Backed by ~/.cache/sccache, capped at 20G with LRU eviction.
# Note: cargo invocations also pick this up via ~/.cargo/config.toml
# (rustc-wrapper = "sccache") regardless of shell.
export RUSTC_WRAPPER=sccache
export SCCACHE_CACHE_SIZE=20G
export SCCACHE_DIR=$HOME/.cache/sccache

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
  local plugdir=/home/rory/sdlc-agent-kit/rust-vanilla-sdlc
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
