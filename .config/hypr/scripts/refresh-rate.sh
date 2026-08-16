#!/usr/bin/env bash

set -u

MONITOR="eDP-1"
RESOLUTION="2880x1920"
POSITION="0x0"
SCALE="1.67"

: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
export XDG_RUNTIME_DIR

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    for sig in $(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null); do
        if [ -S "$XDG_RUNTIME_DIR/hypr/$sig/.socket.sock" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE="$sig"
            break
        fi
    done
fi
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || exit 0 

on_ac() {
    for supply in /sys/class/power_supply/*; do
        [ -r "$supply/type" ] && [ "$(cat "$supply/type")" = "Mains" ] || continue
        [ -r "$supply/online" ] || continue
        [ "$(cat "$supply/online")" = "1" ] && return 0
    done
    return 1
}

if on_ac; then
    rate=120
else
    rate=60
fi

hyprctl eval "hl.monitor({ output = \"$MONITOR\", mode = \"${RESOLUTION}@${rate}\", position = \"$POSITION\", scale = $SCALE })"
