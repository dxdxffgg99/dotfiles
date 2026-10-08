#!/usr/bin/env bash
# Drops the internal panel to 60Hz on battery, restores 120Hz on AC.
#
# 2880x1920 at 120Hz is the single largest battery draw on this machine: it is
# 5.5 megapixels composited by an Iris Xe iGPU. Halving the refresh rate
# roughly halves that compositing work.
#
# Runs from two places, so it has to work in both:
#   - niri spawn-at-startup, where the session env is already set
#   - /etc/udev/rules.d/99-refresh-rate.rules on AC plug/unplug, where it is
#     launched by systemd-run with an empty env and has to find the session

set -u

MONITOR="eDP-1"
RESOLUTION="2880x1920"

: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
export XDG_RUNTIME_DIR

# udev gives us no session env, so recover the compositor socket from the
# runtime dir. Newest wins if a stale one was left behind.
if [ -z "${NIRI_SOCKET:-}" ]; then
    for sock in $(ls -t "$XDG_RUNTIME_DIR"/niri.*.sock 2>/dev/null); do
        if [ -S "$sock" ]; then
            export NIRI_SOCKET="$sock"
            break
        fi
    done
fi
[ -n "${NIRI_SOCKET:-}" ] || exit 0   # no session, nothing to do

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

niri msg output "$MONITOR" mode "${RESOLUTION}@${rate}"
