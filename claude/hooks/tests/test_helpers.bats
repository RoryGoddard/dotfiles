load 'lib/mocks.bash'

setup() {
    setup_mocks
    source "$BATS_TEST_DIRNAME/../_common.sh"
}
teardown() { teardown_mocks; }

@test "state_file_path builds expected path" {
    run state_file_path "work" "3" "%23"
    [ "$status" -eq 0 ]
    [ "$output" = "$CLAUDE_ATTENTION_STATE_DIR/work-3-%23.json" ]
}

@test "state_file_path honors override env var" {
    export CLAUDE_ATTENTION_STATE_DIR=/tmp/xyz
    run state_file_path "s" "1" "%1"
    [ "$output" = "/tmp/xyz/s-1-%1.json" ]
}

@test "resolve_tmux returns empty when TMUX_PANE not set" {
    unset TMUX_PANE
    run resolve_tmux
    [ -z "$output" ]
}

@test "resolve_tmux returns piped fields when TMUX_PANE set" {
    export TMUX_PANE="%23"
    mock_cmd_match tmux 'display-message' 'echo "work|3|backend|%23"'
    run resolve_tmux
    [ "$status" -eq 0 ]
    [ "$output" = "work|3|backend|%23" ]
}

# Build a fake /proc tree under $MOCK_DIR/proc and override readers.
fake_proc() {
    local pid="$1" comm="$2" ppid="$3"
    mkdir -p "$MOCK_DIR/proc/$pid"
    printf 'Name:\t%s\nPid:\t%s\nPPid:\t%s\n' "$comm" "$pid" "$ppid" \
        > "$MOCK_DIR/proc/$pid/status"
}

@test "walk_to_kitty_pid returns kitty PID up the chain" {
    export PROC_ROOT="$MOCK_DIR/proc"
    fake_proc 1000 bash 999
    fake_proc 999  zsh 800
    fake_proc 800  kitty 1
    run walk_to_kitty_pid 1000
    [ "$output" = "800" ]
}

@test "walk_to_kitty_pid returns empty when chain has no kitty" {
    export PROC_ROOT="$MOCK_DIR/proc"
    fake_proc 1000 bash 999
    fake_proc 999  systemd 1
    run walk_to_kitty_pid 1000
    [ -z "$output" ]
}

@test "find_kitty_address picks most-recently-active client and returns hypr addr" {
    export PROC_ROOT="$MOCK_DIR/proc"
    fake_proc 5000 zsh 4000
    fake_proc 4000 kitty 1
    fake_proc 7000 zsh 6000
    fake_proc 6000 kitty 1
    # Two clients; activity desc -> client 5000 first
    mock_cmd_match tmux 'list-clients' 'echo -e "1700000200|5000\n1700000100|7000"'
    mock_cmd_match hyprctl 'clients' 'echo "[{\"pid\":4000,\"address\":\"0xAAA\"},{\"pid\":6000,\"address\":\"0xBBB\"}]"'
    run find_kitty_address "work"
    [ "$output" = "0xAAA" ]
}

@test "find_kitty_address returns empty when no clients" {
    mock_cmd_match tmux 'list-clients' 'true'   # no output
    run find_kitty_address "work"
    [ -z "$output" ]
}
