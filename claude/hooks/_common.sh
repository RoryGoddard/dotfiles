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
