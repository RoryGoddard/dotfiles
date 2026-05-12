#!/usr/bin/env bash
# Tmux pane-focus-in hook target.
# Resolves the focused pane, removes its state file, dismisses swaync notif,
# unsets the per-window tmux flag if no sibling panes still pending.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"

loc="$(tmux display-message -p \
    -F '#{session_name}|#{window_index}|#{pane_id}' 2>/dev/null)"
[[ -z "$loc" ]] && exit 0
IFS='|' read -r sess win pane <<<"$loc"

sf="$(state_file_path "$sess" "$win" "$pane")"
[[ -f "$sf" ]] || exit 0

# Dismiss swaync notification.
swaync_id="$(jq -r '.swaync_id // empty' "$sf" 2>/dev/null || true)"
if [[ -n "$swaync_id" ]]; then
    gdbus call --session \
        --dest=org.freedesktop.Notifications \
        --object-path=/org/freedesktop/Notifications \
        --method=org.freedesktop.Notifications.CloseNotification \
        "$swaync_id" >/dev/null 2>&1 || true
fi

rm -f "$sf"

# If no other panes in this window still pending, unset the tmux flag.
shopt -s nullglob
remaining=("$CLAUDE_ATTENTION_STATE_DIR/$sess-$win-"*.json)
shopt -u nullglob
if (( ${#remaining[@]} == 0 )); then
    tmux set-option -uw -t "$sess:$win" @claude_attention 2>/dev/null || true
fi
