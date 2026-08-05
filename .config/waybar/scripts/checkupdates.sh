#!/usr/bin/env bash
THRESHOLD_MEDIUM=45
THRESHOLD_HIGH=120

# Pacman updates
repo=$(checkupdates 2>/dev/null | wc -l)

# AUR updates
if command -v yay >/dev/null 2>&1; then
    aur=$(yay -Qua 2>/dev/null | wc -l)
else
    aur=0
fi

# Flatpak updates
if command -v flatpak >/dev/null 2>&1; then
    flatpak_updates=$(flatpak remote-ls --updates 2>/dev/null | wc -l)
else
    flatpak_updates=0
fi

total=$((repo + aur + flatpak_updates))

if [ "$total" -lt "$THRESHOLD_MEDIUM" ]; then
    echo '{"text":"","tooltip":"","class":""}'
    exit 0
fi

class="medium"

if [ "$total" -ge "$THRESHOLD_HIGH" ]; then
    class="high"
fi

printf '{"text":"󰚰","tooltip":"Pacman: %s\\nAUR: %s\\nFlatpak: %s\\nTotal: %s","class":"%s"}\n' \
    "$repo" "$aur" "$flatpak_updates" "$total" "$class"
