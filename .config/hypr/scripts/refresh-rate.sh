#!/usr/bin/env bash
# Drops the internal panel to 60Hz on battery, restores 120Hz on AC.
#
# 2880x1920 at 120Hz is the single largest battery draw on this machine: it is
# 5.5 megapixels composited by an Iris Xe iGPU, with blur and shadows on top.
# Halving the refresh rate roughly halves that compositing work.
#
# Runs from two places, so it has to work in both:
#   - hyprland.start, where the session env is already set
#   - /etc/udev/rules.d/99-refresh-rate.rules on AC plug/unplug, where it is
#     launched by systemd-run with an empty env and has to find the session

set -u

MONITOR="eDP-1"
RESOLUTION="2880x1920"
POSITION="0x0"
SCALE="1.67"

: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
export XDG_RUNTIME_DIR

# udev gives us no session env, so recover the compositor instance from the
# socket directory. Newest wins if a stale instance was left behind.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    for sig in $(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null); do
        if [ -S "$XDG_RUNTIME_DIR/hypr/$sig/.socket.sock" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE="$sig"
            break
        fi
    done
fi
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || exit 0   # no session, nothing to do

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

# The config is Lua, and `hyprctl keyword` refuses to touch a non-legacy
# parser, so the mode goes through the Lua API instead. Hyprland ignores a mode
# set that matches the current one, so this is safe to call repeatedly.
hyprctl eval "hl.monitor({ output = \"$MONITOR\", mode = \"${RESOLUTION}@${rate}\", position = \"$POSITION\", scale = $SCALE })"
