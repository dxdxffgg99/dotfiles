#!/usr/bin/env sh
# dotfiles installer -- symlinks (or copies) the configs in this repo into $HOME.
# Usage: ./install.sh [options] [group...]   (see -h)

set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
BACKUP_ROOT=${DOTFILES_BACKUP:-$HOME/.dotfiles-backup}
STAMP=$(date +%Y%m%d-%H%M%S)
TAB=$(printf '\t')

ALL_GROUPS="zsh starship wallpaper kitty waybar rofi hypr nvim btop mako fastfetch"

ACTION=install
MODE=link
DRY_RUN=0
BACKUP=1

if [ -t 1 ]; then
    C_OK=$(printf '\033[32m'); C_INFO=$(printf '\033[36m')
    C_WARN=$(printf '\033[33m'); C_ERR=$(printf '\033[31m')
    C_DIM=$(printf '\033[2m');  C_OFF=$(printf '\033[0m')
else
    C_OK=; C_INFO=; C_WARN=; C_ERR=; C_DIM=; C_OFF=
fi

die() { printf '%s%s%s\n' "$C_ERR" "$*" "$C_OFF" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
act() { printf '  %s%-9s%s %s\n' "$2" "$1" "$C_OFF" "$3"; }

usage() {
    cat <<EOF
Usage: ./install.sh [options] [group...]

Groups (default: all)
  $ALL_GROUPS

Options
  -c, --copy        copy files instead of creating symlinks
  -n, --dry-run     show what would happen, change nothing
  -u, --uninstall   remove symlinks that point into this repo
  -s, --status      show the current state of every managed file
  -d, --deps        check for the programs these configs need
      --no-backup   overwrite existing files without backing them up
  -h, --help        this message

Existing files are moved to $BACKUP_ROOT/<timestamp>/ before being replaced.
EOF
}

# ---------------------------------------------------------------- file mapping

# Prints "<source>\t<destination>" lines for one group.
pairs_for_group() {
    group=$1
    case $group in
        zsh)       printf '%s\t%s\n' "$REPO/.config/.zshrc"        "$HOME/.zshrc" ;;
        starship)  printf '%s\t%s\n' "$REPO/.config/starship.toml" "$CONFIG/starship.toml" ;;
        wallpaper) printf '%s\t%s\n' "$REPO/.config/wp.png"        "$CONFIG/wp.png" ;;
        *)
            dir="$REPO/.config/$group"
            [ -d "$dir" ] || die "unknown group: $group (try: $ALL_GROUPS)"
            find "$dir" -type f ! -name README.md | sort | while read -r src; do
                printf '%s\t%s\n' "$src" "$CONFIG/$group/${src#"$dir/"}"
            done
            ;;
    esac
}

pretty() { case $1 in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

backup() {
    dst=$1
    [ "$BACKUP" -eq 1 ] || { [ "$DRY_RUN" -eq 1 ] || rm -rf -- "$dst"; return; }
    case $dst in
        "$HOME"/*) rel=${dst#"$HOME"/} ;;
        *)         rel=$(printf '%s' "$dst" | sed 's|^/||') ;;
    esac
    saved="$BACKUP_ROOT/$STAMP/$rel"
    act backup "$C_WARN" "$(pretty "$dst") $C_DIM->$C_OFF $(pretty "$saved")"
    [ "$DRY_RUN" -eq 1 ] && return
    mkdir -p -- "$(dirname -- "$saved")"
    mv -- "$dst" "$saved"
}

install_one() {
    src=$1 dst=$2

    if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$src" ] && [ "$MODE" = link ]; then
        act ok "$C_DIM" "$(pretty "$dst") $C_DIM(already linked)$C_OFF"
        return
    fi
    if [ "$MODE" = copy ] && [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s -- "$src" "$dst"; then
        act ok "$C_DIM" "$(pretty "$dst") $C_DIM(unchanged)$C_OFF"
        return
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        backup "$dst"
    fi

    if [ "$MODE" = link ]; then
        act link "$C_OK" "$(pretty "$dst") $C_DIM->$C_OFF ${src#"$REPO"/}"
    else
        act copy "$C_OK" "$(pretty "$dst") $C_DIM<-$C_OFF ${src#"$REPO"/}"
    fi
    [ "$DRY_RUN" -eq 1 ] && return

    mkdir -p -- "$(dirname -- "$dst")"
    if [ "$MODE" = link ]; then
        ln -sfn -- "$src" "$dst"
    else
        cp -p -- "$src" "$dst"
    fi
}

uninstall_one() {
    src=$1 dst=$2
    if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$src" ]; then
        act remove "$C_OK" "$(pretty "$dst")"
        [ "$DRY_RUN" -eq 1 ] || rm -- "$dst"
    elif [ -e "$dst" ]; then
        act keep "$C_WARN" "$(pretty "$dst") $C_DIM(not a link into this repo)$C_OFF"
    fi
}

status_one() {
    src=$1 dst=$2
    if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$src" ]; then
        act linked "$C_OK" "$(pretty "$dst")"
    elif [ -f "$dst" ] && cmp -s -- "$src" "$dst"; then
        act copied "$C_OK" "$(pretty "$dst")"
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
        act differs "$C_WARN" "$(pretty "$dst")"
    else
        act missing "$C_DIM" "$(pretty "$dst")"
    fi
}

# ------------------------------------------------------------------------ deps

check_deps() {
    say "${C_INFO}required${C_OFF}"
    check_cmd zsh          zsh
    check_cmd git          git
    check_cmd Hyprland     hyprland
    check_cmd hyprlock     hyprlock
    check_cmd waybar       waybar
    check_cmd kitty        kitty
    check_cmd rofi         rofi-wayland
    check_cmd nvim         neovim
    check_cmd starship     starship
    check_cmd fastfetch    fastfetch
    check_cmd btop         btop
    check_cmd mako         mako

    say ""
    say "${C_INFO}used by the configs${C_OFF}"
    check_cmd gawk           gawk           "waybar: now playing"
    check_cmd playerctl      playerctl      "waybar: now playing"
    check_cmd nmcli          networkmanager "waybar: network menu"
    check_cmd notify-send    libnotify      "waybar scripts"
    check_cmd checkupdates   pacman-contrib "waybar: updates"
    check_cmd yay            "yay (AUR)"    "waybar: AUR updates"
    check_cmd brightnessctl  brightnessctl  "hypr: brightness keys"
    check_cmd grim           grim           "hypr: screenshots"
    check_cmd slurp          slurp          "hypr: screenshots"
    check_cmd wl-copy        wl-clipboard   "hypr: screenshots"
    check_cmd fcitx5         fcitx5         "hypr: input method"
    check_cmd awww           "awww (AUR)"   "hypr: wallpaper"

    say ""
    say "${C_INFO}zsh plugins${C_OFF}"
    check_dir "$HOME/.oh-my-zsh" "oh-my-zsh"
    check_dir "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "zsh-autosuggestions"
    check_dir "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "zsh-syntax-highlighting"
}

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        act found "$C_OK" "$1"
    else
        act missing "$C_ERR" "$1 $C_DIM($2${3:+, $3})$C_OFF"
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        act found "$C_OK" "$2"
    else
        act missing "$C_ERR" "$2 $C_DIM($(pretty "$1"))$C_OFF"
    fi
}

# ------------------------------------------------------------------------ main

groups=""
while [ $# -gt 0 ]; do
    case $1 in
        -c|--copy)      MODE=copy ;;
        -n|--dry-run)   DRY_RUN=1 ;;
        -u|--uninstall) ACTION=uninstall ;;
        -s|--status)    ACTION=status ;;
        -d|--deps)      ACTION=deps ;;
        --no-backup)    BACKUP=0 ;;
        -h|--help)      usage; exit 0 ;;
        -*)             die "unknown option: $1 (try --help)" ;;
        *)              groups="$groups $1" ;;
    esac
    shift
done

if [ "$ACTION" = deps ]; then
    check_deps
    exit 0
fi

[ -n "$groups" ] || groups=$ALL_GROUPS

list=$(mktemp)
trap 'rm -f "$list"' EXIT INT TERM
for g in $groups; do pairs_for_group "$g" >> "$list"; done

case $ACTION in
    install)   say "${C_INFO}installing${C_OFF} $(printf '%s' "$groups" | sed 's/^ //') ${C_DIM}[$MODE]${C_OFF}" ;;
    uninstall) say "${C_INFO}uninstalling${C_OFF} $(printf '%s' "$groups" | sed 's/^ //')" ;;
    status)    say "${C_INFO}status${C_OFF} $(printf '%s' "$groups" | sed 's/^ //')" ;;
esac
if [ "$DRY_RUN" -eq 1 ]; then say "${C_DIM}dry run -- nothing will be written${C_OFF}"; fi

while IFS="$TAB" read -r src dst; do
    case $ACTION in
        install)   install_one "$src" "$dst" ;;
        uninstall) uninstall_one "$src" "$dst" ;;
        status)    status_one "$src" "$dst" ;;
    esac
done < "$list"

if [ "$ACTION" = install ] && [ "$DRY_RUN" -eq 0 ]; then
    say ""
    say "${C_OK}done.${C_OFF} reload with: ${C_DIM}hyprctl reload${C_OFF} / ${C_DIM}exec zsh${C_OFF}"
    if [ -d "$BACKUP_ROOT/$STAMP" ]; then say "backups: $(pretty "$BACKUP_ROOT/$STAMP")"; fi
fi
exit 0
