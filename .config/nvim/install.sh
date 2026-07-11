#!/bin/bash

set -e

printf "\e[38;5;208m________  ____  ___________  ____  ________________________________/\\  \e[0m\n"     
printf "\e[38;5;208m\\______ \\ \\   \\/  /\\______ \\ \\   \\/  /\\_   _____/\\_   _____/  _____)/ ______\e[0m\n"
printf "\e[38;5;208m |    |  \\ \\     /  |    |  \\ \\     /  |    __)   |    __)/   \\  ___ /  ___/\e[0m\n"
printf "\e[38;5;208m |    \`   \\/     \\  |    \`   \\/     \\  |     \\    |     \\ \\    \\_\\  \\___ \\ \e[0m\n"
printf "\e[38;5;208m/_______  /___/\\  \\/_______  /___/\\  \\ \\___  /    \\___  /  \\______  /____ >\e[0m\n"
printf "\e[38;5;208m        \\/      \\_/        \\/      \\_/     \\/         \\/          \\/     \\/ \e[0m\n"

printf "\n"
printf "\e[38;5;208m________   ______________________________.___.____     ___________ _________\e[0m\n"
printf "\e[38;5;208m\\______ \\  \\_____  \\__    ___/\\_   _____/|   |    |    \\_   _____//   _____/\e[0m\n"
printf "\e[38;5;208m |    |  \\  /   |   \\|    |    |    __)  |   |    |     |    __)_ \\_____  \\ \e[0m\n"
printf "\e[38;5;208m |    \`   \\/    |    \\    |    |     \\   |   |    |___  |        \\/        \\ \e[0m\n"
printf "\e[38;5;208m/_______  /\\_______  /____|    \\___  /   |___|_______ \\/_______  /_______  /\e[0m\n"
printf "\e[38;5;208m        \\/         \\/              \\/                \\/        \\/        \\/ \e[0m\n"

printf "\n"

if ! command -v sudo &> /dev/null; then
    printf "\e[31m[ERROR] sudo is not installed\e[0m\n"
    exit 1
fi

for i in {1..5}; do
  printf "\e[36m%d\e[0m\n" "$i"
  sleep 1
done
printf "\n"

printf "\e[1;32m[install]\e[0m base build requirement\n"
sudo pacman -Syu --noconfirm > /dev/null 2>&1 || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
sudo pacman -S --noconfirm base-devel cmake make git curl > /dev/null 2>&1 || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
printf "\e[32mok\e[0m\n"

printf "\e[1;32m[install]\e[0m neovim\n"
sudo pacman -S --noconfirm neovim > /dev/null 2>&1 || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
printf "\e[32mok\e[0m\n"

printf "\e[1;32m[install]\e[0m compiler (clang, llvm)\n"
sudo pacman -S --noconfirm clang llvm > /dev/null 2>&1 || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
printf "\e[32mok\e[0m\n"

printf "\e[1;32m[install]\e[0m debugger (gdb, lldb)\n"
sudo pacman -S --noconfirm gdb lldb > /dev/null 2>&1 || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
printf "\e[32mok\e[0m\n"

printf "\e[1;32m[install]\e[0m Go, Python, Node.js\n"
sudo pacman -S --noconfirm go python nodejs npm > /dev/null 2>&1 || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
printf "\e[32mok\e[0m\n"

printf "\e[1;32m[install]\e[0m tools (fzf, ripgrep)\n"
sudo pacman -S --noconfirm fzf ripgrep > /dev/null 2>&1 || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
printf "\e[32mok\e[0m\n"

printf "\e[1;32m[install]\e[0m image support (luarocks, imagemagick)\n"
sudo pacman -S --noconfirm luarocks imagemagick > /dev/null 2>&1 || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
printf "\e[32mok\e[0m\n"

printf "\e[1;32m[install]\e[0m Go Delve debugger\n"
go install github.com/go-delve/delve/cmd/dlv@latest > /dev/null 2>&1 || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
printf "\e[32mok\e[0m\n"

printf "\e[1;32m[install]\e[0m Rust LLDB debugger\n"
cargo install lldb-vscode > /dev/null 2>&1 || { printf "\e[33mok (lldb-vscode skipped)\e[0m\n"; }
printf "\e[32mok\e[0m\n"

printf "\e[1;32m[install]\e[0m Neovim config\n"
mkdir -p ~/.config/nvim
curl -fsSL https://raw.githubusercontent.com/dxdxffgg99/dotfiles/main/.config/nvim/init.lua > ~/.config/nvim/init.lua || { printf "\e[31m[FAIL] installation failed\e[0m\n"; exit 1; }
printf "\e[32mok\e[0m\n"

printf "\n"

nvim -c "Lazy" -c "Lazy sync"
