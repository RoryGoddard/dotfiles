# Sourced by every bats test. Sets up a tempdir on PATH containing mock
# binaries that read scripted responses from $MOCK_DIR/responses/.

setup_mocks() {
    export MOCK_DIR="$(mktemp -d)"
    export MOCK_BIN="$MOCK_DIR/bin"
    export MOCK_RESP="$MOCK_DIR/responses"
    export MOCK_LOG="$MOCK_DIR/log"
    mkdir -p "$MOCK_BIN" "$MOCK_RESP"
    : > "$MOCK_LOG"

    # State dir override so tests don't touch real ~/.cache
    export CLAUDE_ATTENTION_STATE_DIR="$MOCK_DIR/state"
    export CLAUDE_ATTENTION_PR_CACHE_DIR="$MOCK_DIR/pr-cache"
    mkdir -p "$CLAUDE_ATTENTION_STATE_DIR" "$CLAUDE_ATTENTION_PR_CACHE_DIR"

    PATH="$MOCK_BIN:$PATH"
}

teardown_mocks() {
    rm -rf "$MOCK_DIR"
}

# Register a mock command. Usage:
#   mock_cmd tmux 'echo "work|3|backend|%23"'
#   mock_cmd gh 'cat <<<"{\"number\":286,\"title\":\"x\"}"'
mock_cmd() {
    local name="$1" body="$2"
    cat > "$MOCK_BIN/$name" <<MOCK
#!/usr/bin/env bash
echo "$name \$*" >> "$MOCK_LOG"
$body
MOCK
    chmod +x "$MOCK_BIN/$name"
}

# Register a mock that returns different output based on args.
# Usage: mock_cmd_match tmux 'list-clients' 'echo "1234"'
mock_cmd_match() {
    local name="$1" pattern="$2" body="$3"
    if [[ ! -f "$MOCK_BIN/$name" ]]; then
        cat > "$MOCK_BIN/$name" <<'HEAD'
#!/usr/bin/env bash
echo "$0 $*" >> "$MOCK_LOG"
HEAD
        chmod +x "$MOCK_BIN/$name"
    fi
    cat >> "$MOCK_BIN/$name" <<MOCK
if [[ "\$*" == *"$pattern"* ]]; then $body; exit 0; fi
MOCK
}

# Get the log of all mock invocations.
mock_calls() {
    cat "$MOCK_LOG"
}
