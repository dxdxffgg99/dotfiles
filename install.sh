#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$DOTFILES_DIR/.config"
CONFIG_DEST="$HOME/.config"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[x]${NC} $*"; }

check_requirements() {
  if [[ ! -f /etc/arch-release ]]; then
    error "err : this dotfiles need arch linux"
    exit 1
  fi

  local kernel
  kernel="$(uname -r)"
  if [[ "$kernel" != *surface* ]]; then
    error "err : this dotfiles need linux-surface kernel"
    exit 1
  fi

  info "OS: Arch Linux"
  info "Kernel: $kernel"
}

PACKAGES=(
  rofi
  kitty
  wl-clipboard
  neovim
  fastfetch
  btop
  waybar
)

install_packages() {
  local to_install=()
  for pkg in "${PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      to_install+=("$pkg")
    else
      info "Already installed: $pkg"
    fi
  done

  if [[ ${#to_install[@]} -gt 0 ]]; then
    info "Installing: ${to_install[*]}"
    sudo pacman -S --needed --noconfirm "${to_install[@]}"
  fi
}

backup_and_link() {
  local src="$1"
  local dest="$2"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
      info "Already linked: $dest"
      return
    fi
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/"
    warn "Backed up existing: $dest → $BACKUP_DIR/"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  info "Linked: $dest → $src"
}

echo ""
echo "  dotfiles installer"
echo "  =================="
echo "  Source : $DOTFILES_DIR"
echo "  Target : $HOME"
echo ""

check_requirements
install_packages

backup_and_link "$CONFIG_SRC/.zshrc" "$HOME/.zshrc"

while IFS= read -r -d '' src; do
  rel="${src#"$CONFIG_SRC/"}"
  dest="$CONFIG_DEST/$rel"
  backup_and_link "$src" "$dest"
done < <(find "$CONFIG_SRC" -mindepth 1 -maxdepth 1 \
           -not -name '.zshrc' -print0)

echo ""
info "Done. $([ -d "$BACKUP_DIR" ] && echo "Backups in $BACKUP_DIR" || echo "No backups needed.")"
