#!/usr/bin/env bash
# Toggle hypridle on/off (manual caffeine mode)
# Sends a notification showing current state

if pgrep -x hypridle > /dev/null; then
    killall hypridle
    notify-send -u normal -t 3000 "Caffeine ON" "Idle inhibitor active — screen will not lock"
else
    hypridle &
    disown
    notify-send -u normal -t 3000 "Caffeine OFF" "Normal idle behavior resumed"
fi
