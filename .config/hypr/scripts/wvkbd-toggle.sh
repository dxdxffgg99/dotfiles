#!/usr/bin/env bash
# Shows/hides wvkbd only when no physical keyboard is attached.

has_physical_keyboard() {
    hyprctl devices -j | jq -e '
        .keyboards
        | map(select(.name | test("^gpio-keys|^video-bus|virtual-keyboard|^logitech-g304$"; "i") | not))
        | length > 0
    ' >/dev/null
}

case "$1" in
    show)
        has_physical_keyboard || pkill -SIGUSR2 wvkbd-mobintl
        ;;
    hide)
        pkill -SIGUSR1 wvkbd-mobintl
        ;;
esac
