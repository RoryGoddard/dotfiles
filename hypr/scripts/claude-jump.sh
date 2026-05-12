#!/usr/bin/env bash
# Hyprland keybind: jump to the oldest pending Claude Code attention request.

set -uo pipefail

: "${CLAUDE_ATTENTION_STATE_DIR:=$HOME/.cache/claude-attention}"

shopt -s nullglob
files=("$CLAUDE_ATTENTION_STATE_DIR"/*.json)
shopt -u nullglob
(( ${#files[@]} == 0 )) && exit 0

# Sort by mtime ascending (oldest first), pick first.
oldest="$(printf '%s\n' "${files[@]}" | xargs -d '\n' stat -c '%Y %n' \
    | sort -n | head -n1 | cut -d' ' -f2-)"
[[ -z "$oldest" ]] && exit 0

read -r sess win pane kitty <<<"$(jq -r \
    '[.session,.window,.pane_id,(.kitty_address // "")] | @tsv' \
    "$oldest" 2>/dev/null)"
[[ -z "$sess" ]] && exit 0

if [[ -n "$kitty" ]]; then
    hyprctl dispatch focuswindow address:"$kitty" >/dev/null 2>&1 || true
fi

tmux select-window -t "$sess:$win" 2>/dev/null || true
tmux select-pane -t "$pane" 2>/dev/null || true
