load 'lib/mocks.bash'

setup() { setup_mocks; }
teardown() { teardown_mocks; }

@test "notification event writes state file and fires notify-send" {
    export TMUX_PANE="%23"
    export PROC_ROOT="$MOCK_DIR/proc"
    mkdir -p "$PROC_ROOT/$$"
    printf 'Name:\tbash\nPid:\t%s\nPPid:\t1\n' "$$" > "$PROC_ROOT/$$/status"

    mock_cmd_match tmux 'display-message' 'echo "work|\$0|3|@5|backend|%23"'
    mock_cmd_match tmux 'list-clients' 'true'   # no clients → null kitty addr
    mock_cmd_match tmux 'set-option' 'true'
    mock_cmd notify-send 'echo 4127'  # --print-id output
    mock_cmd hyprctl 'echo "[]"'
    mock_cmd gh 'exit 1'

    payload='{"hook_event_name":"Notification","cwd":"/tmp/x","message":"Approve: rm -rf"}'
    run bash -c "echo '$payload' | $BATS_TEST_DIRNAME/../attention-fire.sh notification"
    [ "$status" -eq 0 ]

    state="$CLAUDE_ATTENTION_STATE_DIR/@5-%23.json"
    [ -f "$state" ]
    [ "$(jq -r .session "$state")" = "work" ]
    [ "$(jq -r .session_id "$state")" = '$0' ]
    [ "$(jq -r .window "$state")" = "3" ]
    [ "$(jq -r .window_id "$state")" = "@5" ]
    [ "$(jq -r .pane_id "$state")" = "%23" ]
    [ "$(jq -r .message "$state")" = "Approve: rm -rf" ]
    [ "$(jq -r .swaync_id "$state")" = "4127" ]
}

@test "stop event without CLAUDE_NOTIFY_ON_STOP returns silently" {
    export TMUX_PANE="%23"
    unset CLAUDE_NOTIFY_ON_STOP
    mock_cmd_match tmux 'display-message' 'echo "work|\$0|3|@5|backend|%23"'
    mock_cmd notify-send 'echo "SHOULD_NOT_BE_CALLED"'

    payload='{"hook_event_name":"Stop","cwd":"/tmp/x"}'
    run bash -c "echo '$payload' | $BATS_TEST_DIRNAME/../attention-fire.sh stop"
    [ "$status" -eq 0 ]
    ! grep -q SHOULD_NOT_BE_CALLED "$MOCK_LOG"
    [ ! -f "$CLAUDE_ATTENTION_STATE_DIR/@5-%23.json" ]
}

@test "stop event with CLAUDE_NOTIFY_ON_STOP suppresses when pane is focused" {
    skip "Focus-suppression integration test — covered by manual smoke test 5"
}
