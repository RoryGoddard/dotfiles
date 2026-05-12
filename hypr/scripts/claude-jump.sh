#!/usr/bin/env bash
# Hyprland keybind: jump to the oldest pending Claude Code attention request.

set -uo pipefail

: "${CLAUDE_ATTENTION_STATE_DIR:=$HOME/.cache/claude-attention}"

win_id="" pane="" kitty=""

while true; do
    shopt -s nullglob
    files=("$CLAUDE_ATTENTION_STATE_DIR"/*.json)
    shopt -u nullglob
    (( ${#files[@]} == 0 )) && exit 0

    # Sort by mtime ascending (oldest first), pick first.
    oldest="$(printf '%s\n' "${files[@]}" | xargs -d '\n' stat -c '%Y %n' \
        | sort -n | head -n1 | cut -d' ' -f2-)"
    [[ -z "$oldest" ]] && exit 0

    read -r win_id pane kitty <<<"$(jq -r \
        '[.window_id,.pane_id,(.kitty_address // "")] | @tsv' \
        "$oldest" 2>/dev/null)"

    if [[ -z "$win_id" ]] || ! tmux display-message -p -t "$win_id" '#{window_id}' >/dev/null 2>&1; then
        # Stale: window no longer exists. Remove and try next.
        rm -f "$oldest"
        continue
    fi

    break
done

if [[ -n "$kitty" ]]; then
    hyprctl dispatch focuswindow address:"$kitty" >/dev/null 2>&1 || true
fi
tmux select-window -t "$win_id" 2>/dev/null || true
tmux select-pane -t "$pane" 2>/dev/null || true
