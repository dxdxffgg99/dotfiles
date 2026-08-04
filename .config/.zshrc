clear

if [[ -z "$FIRST_OPEN_SHELL" ]]; then
    export FIRST_OPEN_SHELL=1

    ZSH_THEME=""

    plugins=()

    source ~/.oh-my-zsh/oh-my-zsh.sh

    zmodload zsh/sched
    sched +0 '
        source ~/.oh-my-zsh/plugins/git/git.plugin.zsh
        source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
        source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        ZSH_HIGHLIGHT_STYLES[command]="fg=cyan,bold"
        ZSH_HIGHLIGHT_STYLES[builtin]="fg=blue,bold"
        ZSH_HIGHLIGHT_STYLES[alias]="fg=magenta,bold"
        ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=yellow"
        ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=yellow"
    '

    alias la='ls -lha'
    alias reload='source ~/.zshrc'
    alias cd..='cd ..'

    STARSHIP_CACHE="$HOME/.cache/starship-init.zsh"
    STARSHIP_VERSION_FILE="$HOME/.cache/starship-version"
    if [[ ! -f "$STARSHIP_CACHE" || "$(starship --version)" != "$(cat "$STARSHIP_VERSION_FILE" 2>/dev/null)" ]]; then
        starship init zsh > "$STARSHIP_CACHE"
        starship --version > "$STARSHIP_VERSION_FILE"
    fi
    source "$STARSHIP_CACHE"

    (fastfetch &) 2>/dev/null
fi