ZSH_THEME="agnoster"

plugins=(
    git
    zsh-syntax-highlighting
    zsh-autosuggestions
    web-search
)

source ~/.oh-my-zsh/oh-my-zsh.sh

ZSH_HIGHLIGHT_STYLES[command]='fg=cyan,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=blue,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=magenta,bold'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=yellow'

alias la='ls -lha'
alias reload='source ~/.zshrc'
alias cls='clear'
alias cd..='cd ..'

clear && fastfetch

export ZSH_COMPDUMP="$HOME/.cache/oh-my-zsh/.zcompdump-$HOST"
