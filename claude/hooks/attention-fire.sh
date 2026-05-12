#!/usr/bin/env bash
# Claude Code Notification + Stop hook entrypoint.
# Usage: attention-fire.sh <notification|stop>
# Reads hook JSON from stdin.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"

event="${1:-notification}"
payload="$(cat)"

# Resolve tmux location; bail silently if not in tmux.
loc="$(resolve_tmux)"
[[ -z "$loc" ]] && exit 0
IFS='|' read -r sess win wname pane <<<"$loc"

# Stop-only short-circuit: opt-in via env, then suppress if user is watching.
if [[ "$event" == "stop" ]]; then
    [[ -z "${CLAUDE_NOTIFY_ON_STOP:-}" ]] && exit 0

    # Focus check: skip if this pane is the focused pane in the focused kitty.
    pane_active="$(tmux display-message -p -t "$pane" -F '#{window_active}' 2>/dev/null)"
    if [[ "$pane_active" == "1" ]]; then
        my_kitty="$(find_kitty_address "$sess")"
        active_addr="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')"
        if [[ -n "$my_kitty" && "$my_kitty" == "$active_addr" ]]; then
            exit 0
        fi
    fi
fi

cwd="$(jq -r '.cwd // empty' <<<"$payload")"
message="$(jq -r '.message // ""' <<<"$payload")"
[[ "$event" == "stop" && -z "$message" ]] && message="Claude finished"

# Build context.
kitty_addr="$(find_kitty_address "$sess")"
rb="$(resolve_repo_branch "$cwd")"
repo=""; branch=""
if [[ -n "$rb" ]]; then IFS='|' read -r repo branch <<<"$rb"; fi
pr_json="$(fetch_pr_cached "$cwd")"

# Re-fire: read prior swaync_id if state file exists.
sf="$(state_file_path "$sess" "$win" "$pane")"
prior_id=""
if [[ -f "$sf" ]]; then
    prior_id="$(jq -r '.swaync_id // empty' "$sf" 2>/dev/null || true)"
fi

# Build notification.
title="$(build_notification_title "$sess" "$win" "$wname")"
body="$(build_notification_body "$repo" "$branch" "$pr_json" "$message")"
urgency="critical"
[[ "$event" == "stop" ]] && urgency="normal"

ns_args=(--app-name=claude-code --urgency="$urgency" --print-id)
# --replace-id is libnotify >= 0.8 (Ubuntu 24.04+). If unsupported, we drop it
# silently — worst case is a duplicate notification on rapid re-fire.
if [[ -n "$prior_id" ]] && notify-send --help 2>&1 | grep -q -- '--replace-id'; then
    ns_args+=(--replace-id="$prior_id")
fi
swaync_id="$(notify-send "${ns_args[@]}" "$title" "$body" 2>/dev/null || echo "")"

# Write state file atomically.
mkdir -p "$CLAUDE_ATTENTION_STATE_DIR"
tmp="$(mktemp "$sf.XXXX")"
jq -n \
    --arg sess "$sess" --arg win "$win" --arg wname "$wname" --arg pane "$pane" \
    --arg kitty "$kitty_addr" --arg cwd "$cwd" --arg repo "$repo" --arg branch "$branch" \
    --argjson pr "${pr_json:-null}" --arg message "$message" --arg event "$event" \
    --arg swaync_id "$swaync_id" \
    '{session:$sess, window:($win|tonumber), window_name:$wname, pane_id:$pane,
      kitty_address:($kitty|select(length>0) // null), cwd:$cwd,
      repo:($repo|select(length>0) // null), branch:($branch|select(length>0) // null),
      pr:$pr, message:$message, event:$event,
      swaync_id:($swaync_id|select(length>0)|tonumber? // null),
      timestamp:(now|floor)}' > "$tmp"
mv "$tmp" "$sf"

# Set the tmux window flag.
tmux set-option -w -t "$sess:$win" @claude_attention 1 2>/dev/null || true
