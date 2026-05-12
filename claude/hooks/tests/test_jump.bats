load 'lib/mocks.bash'

setup() { setup_mocks; }
teardown() { teardown_mocks; }

@test "jump is no-op when cache is empty" {
    run bash "$BATS_TEST_DIRNAME/../../../hypr/scripts/claude-jump.sh"
    [ "$status" -eq 0 ]
}

@test "jump picks oldest by mtime, dispatches hyprctl + tmux" {
    cat > "$CLAUDE_ATTENTION_STATE_DIR/@5-%1.json" <<'JSON'
{"session":"a","window":1,"window_id":"@5","pane_id":"%1","kitty_address":"0xOLD"}
JSON
    touch -d '5 minutes ago' "$CLAUDE_ATTENTION_STATE_DIR/@5-%1.json"
    cat > "$CLAUDE_ATTENTION_STATE_DIR/@7-%2.json" <<'JSON'
{"session":"b","window":2,"window_id":"@7","pane_id":"%2","kitty_address":"0xNEW"}
JSON

    mock_cmd hyprctl 'true'
    mock_cmd_match tmux 'display-message' 'true'
    mock_cmd_match tmux 'select-window' 'true'
    mock_cmd_match tmux 'select-pane' 'true'

    run bash "$BATS_TEST_DIRNAME/../../../hypr/scripts/claude-jump.sh"
    [ "$status" -eq 0 ]
    grep -q 'hyprctl dispatch focuswindow address:0xOLD' "$MOCK_LOG"
    grep -q 'tmux select-window -t @5' "$MOCK_LOG"
    grep -q 'tmux select-pane -t %1' "$MOCK_LOG"
}

@test "jump handles null kitty_address by skipping hyprctl focus" {
    cat > "$CLAUDE_ATTENTION_STATE_DIR/@5-%1.json" <<'JSON'
{"session":"a","window":1,"window_id":"@5","pane_id":"%1","kitty_address":null}
JSON

    mock_cmd hyprctl 'echo "SHOULD_NOT_FOCUS"'
    mock_cmd_match tmux 'display-message' 'true'
    mock_cmd_match tmux 'select-window' 'true'
    mock_cmd_match tmux 'select-pane' 'true'

    run bash "$BATS_TEST_DIRNAME/../../../hypr/scripts/claude-jump.sh"
    [ "$status" -eq 0 ]
    ! grep -q 'hyprctl dispatch focuswindow' "$MOCK_LOG"
    grep -q 'tmux select-window -t @5' "$MOCK_LOG"
}
