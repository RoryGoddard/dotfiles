#!/usr/bin/env bash
# Shared helpers for Claude Code attention routing.
# Sourced by attention-fire.sh, attention-clear.sh, claude-jump.sh.

: "${CLAUDE_ATTENTION_STATE_DIR:=$HOME/.cache/claude-attention}"
: "${CLAUDE_ATTENTION_PR_CACHE_DIR:=$HOME/.cache/claude-attention/pr-cache}"
: "${CLAUDE_ATTENTION_PR_TTL:=60}"

state_file_path() {
    local sess="$1" win="$2" pane="$3"
    printf '%s/%s-%s-%s.json\n' "$CLAUDE_ATTENTION_STATE_DIR" "$sess" "$win" "$pane"
}

resolve_tmux() {
    [[ -z "$TMUX_PANE" ]] && return 0
    tmux display-message -p -t "$TMUX_PANE" \
        -F '#{session_name}|#{window_index}|#{window_name}|#{pane_id}' 2>/dev/null
}

: "${PROC_ROOT:=/proc}"

walk_to_kitty_pid() {
    local pid="$1"
    local depth=0
    while [[ -n "$pid" && "$pid" != "0" && "$pid" != "1" && $depth -lt 32 ]]; do
        local status="$PROC_ROOT/$pid/status"
        [[ -r "$status" ]] || return 0
        local comm
        comm=$(awk -F'\t' '/^Name:/ {print $2; exit}' "$status")
        if [[ "$comm" == "kitty" ]]; then
            printf '%s\n' "$pid"
            return 0
        fi
        pid=$(awk -F'\t' '/^PPid:/ {print $2; exit}' "$status")
        ((depth++))
    done
}

find_kitty_address() {
    local sess="$1"
    local clients
    clients=$(tmux list-clients -t "$sess" -F '#{client_activity}|#{client_pid}' 2>/dev/null \
        | sort -t'|' -k1,1 -nr)
    [[ -z "$clients" ]] && return 0

    local kitty_pids=()
    while IFS='|' read -r _ cpid; do
        [[ -n "$cpid" ]] || continue
        local kpid
        kpid=$(walk_to_kitty_pid "$cpid")
        [[ -n "$kpid" ]] && kitty_pids+=("$kpid")
    done <<< "$clients"

    [[ ${#kitty_pids[@]} -eq 0 ]] && return 0

    local first_pid="${kitty_pids[0]}"
    hyprctl clients -j 2>/dev/null \
        | jq -r --argjson pid "$first_pid" '.[] | select(.pid == $pid) | .address' \
        | head -n1
}

resolve_repo_branch() {
    local cwd="$1"
    local toplevel
    toplevel=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || return 0
    local branch
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null) || return 0
    printf '%s|%s\n' "$(basename "$toplevel")" "$branch"
}
