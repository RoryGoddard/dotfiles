# Claude Code Attention Routing

Bridges Claude Code → tmux dot + swaync notification → Hyprland keybind.

## Files
- `_common.sh` — shared helpers (tmux/kitty/git/PR resolution, formatters)
- `attention-fire.sh` — Notification + Stop + AskUserQuestion hook entrypoint
- `attention-clear.sh` — tmux pane-focus-in hook target

Hyprland-side: `~/.dotfiles/hypr/scripts/claude-jump.sh`.

## Wiring
- Registered as Claude Code hooks in `~/.claude/settings.json`:
  - `Notification` → `attention-fire.sh notification` (permission prompts, 60s idle)
  - `Stop` → `attention-fire.sh stop` (turn finished; opt-in via `CLAUDE_NOTIFY_ON_STOP`)
  - `PreToolUse` matcher `AskUserQuestion` → `attention-fire.sh askuserquestion`
- Set `agentPushNotifEnabled: false` in `~/.claude/settings.json` so the hook is the single notification source (avoids double-notify on AskUserQuestion).
- tmux: `set-hook -g pane-focus-in 'run-shell -b "~/.config/claude/hooks/attention-clear.sh"'`
- Hyprland: `bind = $mainMod, space, exec, ~/.config/hypr/scripts/claude-jump.sh`

## Env vars
- `CLAUDE_NOTIFY_ON_STOP=1` — opt in to Stop-hook notifications (off by default).
- `CLAUDE_ATTENTION_STATE_DIR` — override state dir (default `~/.cache/claude-attention`).
- `CLAUDE_ATTENTION_PR_TTL` — PR lookup cache TTL in seconds (default 60).

## Tests

    bats ~/.dotfiles/claude/hooks/tests/

## Design doc
`~/.config/doc/2026-05-07-claude-tmux-attention-design.md`
