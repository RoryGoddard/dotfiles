#!/usr/bin/env bash
# Automatically inhibit idle when audio is playing
# Monitors PipeWire/PulseAudio sink inputs and pauses hypridle when audio streams are active

POLL_INTERVAL=10  # seconds between checks
inhibited=false

cleanup() {
    # Restore hypridle if we killed it
    if [ "$inhibited" = true ] && ! pgrep -x hypridle > /dev/null; then
        hypridle &
        disown
    fi
    exit 0
}
trap cleanup EXIT INT TERM

has_audio_streams() {
    # Check if any sink-input (audio playback stream) is currently running
    pactl list sink-inputs short 2>/dev/null | grep -q RUNNING
}

while true; do
    if has_audio_streams; then
        if [ "$inhibited" = false ]; then
            # Audio started — kill hypridle
            if pgrep -x hypridle > /dev/null; then
                killall hypridle
                notify-send -u low -t 2000 "Audio detected" "Idle inhibitor active"
            fi
            inhibited=true
        fi
    else
        if [ "$inhibited" = true ]; then
            # Audio stopped — restart hypridle
            if ! pgrep -x hypridle > /dev/null; then
                hypridle &
                disown
                notify-send -u low -t 2000 "Audio stopped" "Normal idle behavior resumed"
            fi
            inhibited=false
        fi
    fi
    sleep "$POLL_INTERVAL"
done
