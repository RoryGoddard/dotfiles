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
IFS='|' read -r sess sess_id win win_id wname pane <<<"$loc"

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
# Only fetch PR for non-default branches — the default branch's PR (typically
# a long-lived sync/release PR) is noise across many sessions in the same repo.
if [[ -n "$branch" ]] && ! is_default_branch "$cwd" "$branch"; then
    pr_json="$(fetch_pr_cached "$cwd")"
else
    pr_json=""
fi

# Re-fire: read prior swaync_id if state file exists.
sf="$(state_file_path "$win_id" "$pane")"
prior_id=""
if [[ -f "$sf" ]]; then
    prior_id="$(jq -r '.swaync_id // empty' "$sf" 2>/dev/null || true)"
fi

# Build notification.
# Urgency stays "normal" for both event types — swaync ignores --expire-time
# when urgency is critical, which would make the toast persist forever
# (timeout-critical: 0 in swaync's defaults). The tmux dot already conveys
# "needs attention" so the urgency level adds little.
title="$(build_notification_title "$sess" "$win" "$wname")"
body="$(build_notification_body "$repo" "$branch" "$pr_json" "$message")"

ns_args=(--app-name=claude-code --urgency=normal --expire-time="$CLAUDE_ATTENTION_TIMEOUT_MS" --print-id)
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
    --arg sess "$sess" --arg sess_id "$sess_id" \
    --arg win "$win" --arg win_id "$win_id" \
    --arg wname "$wname" --arg pane "$pane" \
    --arg kitty "$kitty_addr" --arg cwd "$cwd" --arg repo "$repo" --arg branch "$branch" \
    --argjson pr "${pr_json:-null}" --arg message "$message" --arg event "$event" \
    --arg swaync_id "$swaync_id" \
    '{session:$sess, session_id:$sess_id,
      window:($win|tonumber), window_id:$win_id,
      window_name:$wname, pane_id:$pane,
      kitty_address:($kitty|select(length>0) // null), cwd:$cwd,
      repo:($repo|select(length>0) // null), branch:($branch|select(length>0) // null),
      pr:$pr, message:$message, event:$event,
      swaync_id:($swaync_id|select(length>0)|tonumber? // null),
      timestamp:(now|floor)}' > "$tmp"
mv "$tmp" "$sf"

# Set the tmux window flag.
tmux set-option -w -t "$win_id" @claude_attention 1 2>/dev/null || true
