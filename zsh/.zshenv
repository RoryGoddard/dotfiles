[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# Single shared SSH agent: Omarchy's ssh-agent.socket user unit. Matches
# ~/.config/environment.d/10-ssh-agent.conf (services + graphical session), so a
# passphrase-unlocked key is reachable in every shell, not only interactive ones.
if [[ -n $XDG_RUNTIME_DIR ]]; then
  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
fi

# Reconnect the Wayland clipboard when this shell was launched with a bare env
# (e.g. herdr's systemd-user server, which snapshots its env before Hyprland
# imports WAYLAND_DISPLAY). Without this, wl-paste can't reach the compositor
# and Claude Code screenshot paste silently fails. tmux doesn't need it because
# it inherits WAYLAND_DISPLAY from the terminal that started it.
if [[ -z $WAYLAND_DISPLAY && -n $XDG_RUNTIME_DIR ]]; then
  for _s in "$XDG_RUNTIME_DIR"/wayland-*(N); do
    [[ -S $_s ]] || continue        # a socket, not the wayland-N.lock file
    export WAYLAND_DISPLAY=${_s:t}
    break
  done
  unset _s
fi

# Editor for git, crontab, gh, sudoedit, zsh <C-x><C-e>. Both: VISUAL wins when
# set, and some tools check only one. Here, not .zshrc, so scripts see it too.
export EDITOR=nvim
export VISUAL=nvim
