load 'lib/mocks.bash'

setup() { setup_mocks; }
teardown() { teardown_mocks; }

@test "clear is no-op when no state file exists" {
    mock_cmd_match tmux 'display-message' 'echo "work|3|%23"'
    run bash "$BATS_TEST_DIRNAME/../attention-clear.sh"
    [ "$status" -eq 0 ]
}

@test "clear removes the state file and unsets tmux flag (last pane)" {
    mock_cmd_match tmux 'display-message' 'echo "work|3|%23"'
    mock_cmd_match tmux 'set-option' 'echo "set-option called"'
    mock_cmd gdbus 'true'

    sf="$CLAUDE_ATTENTION_STATE_DIR/work-3-%23.json"
    echo '{"swaync_id":4127}' > "$sf"

    run bash "$BATS_TEST_DIRNAME/../attention-clear.sh"
    [ "$status" -eq 0 ]
    [ ! -f "$sf" ]
    grep -q "set-option" "$MOCK_LOG"
    grep -q 'gdbus.*CloseNotification.*4127' "$MOCK_LOG"
}

@test "clear keeps tmux flag when sibling panes still pending" {
    mock_cmd_match tmux 'display-message' 'echo "work|3|%23"'
    mock_cmd_match tmux 'set-option' 'echo "set-option called"'
    mock_cmd gdbus 'true'

    echo '{"swaync_id":1}' > "$CLAUDE_ATTENTION_STATE_DIR/work-3-%23.json"
    echo '{"swaync_id":2}' > "$CLAUDE_ATTENTION_STATE_DIR/work-3-%24.json"

    run bash "$BATS_TEST_DIRNAME/../attention-clear.sh"
    [ "$status" -eq 0 ]
    [ ! -f "$CLAUDE_ATTENTION_STATE_DIR/work-3-%23.json" ]
    [ -f "$CLAUDE_ATTENTION_STATE_DIR/work-3-%24.json" ]
    ! grep -q "set-option" "$MOCK_LOG"
}
