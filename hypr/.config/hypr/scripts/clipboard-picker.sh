#!/usr/bin/env bash
# Clipboard history picker (cliphist + wofi).
#
# Every early exit below is load-bearing: wl-copy given an empty stdin sets an
# *empty* selection rather than doing nothing, so a cancelled picker would
# silently destroy whatever was on the clipboard (e.g. a fresh screenshot).
set -uo pipefail

# wofi exits non-zero when dismissed with Escape.
selection=$(cliphist list | wofi --dmenu) || exit 0
[ -n "$selection" ] || exit 0

# Decode through a file, not a variable: entries may be binary (PNG), and
# command substitution strips NUL bytes and trailing newlines.
decoded=$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" clipboard-picker.XXXXXX) || exit 1
trap 'rm -f "$decoded"' EXIT

printf '%s\n' "$selection" | cliphist decode >"$decoded" || exit 0
[ -s "$decoded" ] || exit 0

wl-copy <"$decoded"
