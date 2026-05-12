#!/usr/bin/env bash
# Shared helpers for Claude Code attention routing.
# Sourced by attention-fire.sh, attention-clear.sh, claude-jump.sh.

: "${CLAUDE_ATTENTION_STATE_DIR:=$HOME/.cache/claude-attention}"
: "${CLAUDE_ATTENTION_PR_CACHE_DIR:=$HOME/.cache/claude-attention/pr-cache}"
: "${CLAUDE_ATTENTION_PR_TTL:=60}"

state_file_path() {
    local win_id="$1" pane_id="$2"
    printf '%s/%s-%s.json\n' "$CLAUDE_ATTENTION_STATE_DIR" "$win_id" "$pane_id"
}

resolve_tmux() {
    [[ -z "$TMUX_PANE" ]] && return 0
    tmux display-message -p -t "$TMUX_PANE" \
        -F '#{session_name}|#{session_id}|#{window_index}|#{window_id}|#{window_name}|#{pane_id}' 2>/dev/null
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

# Returns 0 if the given branch is the repo's default (main/master/develop/etc).
# Detection: `git symbolic-ref refs/remotes/origin/HEAD` for the authoritative
# answer; falls back to a common-name list if origin/HEAD isn't set.
is_default_branch() {
    local cwd="$1" branch="$2"
    [[ -z "$cwd" || -z "$branch" ]] && return 1
    local default
    default=$(git -C "$cwd" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
        | sed 's|^refs/remotes/origin/||')
    if [[ -z "$default" ]]; then
        case "$branch" in
            main|master|develop|trunk) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ "$branch" == "$default" ]]
}

fetch_pr_cached() {
    local cwd="$1"
    mkdir -p "$CLAUDE_ATTENTION_PR_CACHE_DIR"
    local key cache
    key=$(printf '%s' "$cwd" | sha1sum | awk '{print $1}')
    cache="$CLAUDE_ATTENTION_PR_CACHE_DIR/$key.json"

    if [[ -f "$cache" ]]; then
        local age
        age=$(( $(date +%s) - $(stat -c %Y "$cache") ))
        if (( age < CLAUDE_ATTENTION_PR_TTL )); then
            cat "$cache"
            return 0
        fi
    fi

    local out
    out=$(cd "$cwd" 2>/dev/null && gh pr view --json number,title 2>/dev/null) || out=""
    if [[ -n "$out" ]]; then
        printf '%s' "$out" > "$cache"
        printf '%s\n' "$out"
    fi
}

build_notification_title() {
    local sess="$1" win="$2" wname="$3"
    printf 'Claude • %s:%s %s\n' "$sess" "$win" "$wname"
}

build_notification_body() {
    local repo="$1" branch="$2" pr_json="$3" message="$4"
    local lines=()

    if [[ -n "$repo" && -n "$branch" ]]; then
        local line="$repo @ $branch"
        if [[ -n "$pr_json" ]]; then
            local n t
            n=$(jq -r '.number // empty' <<<"$pr_json")
            t=$(jq -r '.title // empty' <<<"$pr_json")
            if [[ -n "$n" ]]; then
                line="$line · PR #$n $t"
            fi
        fi
        lines+=("$line")
        lines+=("")
    fi
    lines+=("$message")

    printf '%s\n' "${lines[@]}"
}
