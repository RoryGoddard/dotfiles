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

@test "resolve_repo_branch returns repo|branch in a git checkout" {
    local repo="$MOCK_DIR/myapp"
    git init -q "$repo"
    git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    git -C "$repo" checkout -q -b feature/auth
    run resolve_repo_branch "$repo"
    [ "$output" = "myapp|feature/auth" ]
}

@test "resolve_repo_branch returns empty when not a git repo" {
    mkdir -p "$MOCK_DIR/notagit"
    run resolve_repo_branch "$MOCK_DIR/notagit"
    [ -z "$output" ]
}

@test "fetch_pr_cached returns gh JSON and caches it" {
    mkdir -p "$MOCK_DIR/somepath"
    mock_cmd gh 'echo "{\"number\":286,\"title\":\"Add OAuth\"}"'
    run fetch_pr_cached "$MOCK_DIR/somepath"
    [ "$status" -eq 0 ]
    [ "$output" = '{"number":286,"title":"Add OAuth"}' ]
    # Second call: replace gh with one that fails — should still serve from cache
    mock_cmd gh 'exit 1'
    run fetch_pr_cached "$MOCK_DIR/somepath"
    [ "$output" = '{"number":286,"title":"Add OAuth"}' ]
}

@test "fetch_pr_cached returns empty when gh fails on first call" {
    mkdir -p "$MOCK_DIR/x"
    mock_cmd gh 'exit 1'
    run fetch_pr_cached "$MOCK_DIR/x"
    [ -z "$output" ]
}

@test "fetch_pr_cached refreshes after TTL expiry" {
    mkdir -p "$MOCK_DIR/x"
    mock_cmd gh 'echo "{\"number\":1,\"title\":\"old\"}"'
    fetch_pr_cached "$MOCK_DIR/x" >/dev/null
    # Backdate the cache file
    local key
    key=$(printf '%s' "$MOCK_DIR/x" | sha1sum | awk '{print $1}')
    touch -d '2 minutes ago' "$CLAUDE_ATTENTION_PR_CACHE_DIR/$key.json"
    mock_cmd gh 'echo "{\"number\":2,\"title\":\"new\"}"'
    run fetch_pr_cached "$MOCK_DIR/x"
    [ "$output" = '{"number":2,"title":"new"}' ]
}

@test "build_notification_title formats session window window-name" {
    run build_notification_title "work" "3" "backend"
    [ "$output" = "Claude • work:3 backend" ]
}

@test "build_notification_body includes repo, branch, PR, message" {
    run build_notification_body "myapp" "feature/auth" '{"number":286,"title":"Add OAuth"}' "Approve: rm -rf node_modules"
    expected=$'myapp @ feature/auth · PR #286 Add OAuth\n\nApprove: rm -rf node_modules'
    [ "$output" = "$expected" ]
}

@test "build_notification_body omits PR line when no PR" {
    run build_notification_body "myapp" "feature/auth" '' "do thing"
    expected=$'myapp @ feature/auth\n\ndo thing'
    [ "$output" = "$expected" ]
}

@test "build_notification_body omits repo+branch line when not a repo" {
    run build_notification_body '' '' '' "do thing"
    [ "$output" = "do thing" ]
}
