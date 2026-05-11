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
