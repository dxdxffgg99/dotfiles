setopt always_to_end auto_cd auto_pushd complete_in_word interactive_comments
setopt long_list_jobs no_flow_control prompt_subst pushd_ignore_dups pushd_minus

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history hist_expire_dups_first hist_ignore_dups
setopt hist_ignore_space hist_verify share_history

autoload -Uz compinit colors add-zsh-hook is-at-least
colors

ZCOMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
if [[ -n "$ZCOMPDUMP"(#qN.mh+24) ]]; then
    compinit -d "$ZCOMPDUMP"
else
    compinit -C -d "$ZCOMPDUMP"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zcompcache"
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
[[ -n "$LS_COLORS" ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

alias -- -='cd -'
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'
for i in {1..9}; do alias "$i"="cd -$i"; done; unset i
alias _='sudo'
alias md='mkdir -p'
alias rd=rmdir
alias history='fc -l 1'

alias ls='ls --color=tty'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -lha'
alias lsa='ls -lah'
alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv}'
alias egrep='grep -E'
alias fgrep='grep -F'

alias reload='clear && source ~/.zshrc'
alias cd..='cd ..'

if [[ -z "$_ZSH_PLUGINS_LOADED" ]]; then
    typeset -g _ZSH_PLUGINS_LOADED=1
    zmodload zsh/sched
    sched +0 '
        source ~/.oh-my-zsh/lib/git.zsh
        source ~/.oh-my-zsh/plugins/git/git.plugin.zsh
        source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
        source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        ZSH_HIGHLIGHT_STYLES[command]="fg=cyan,bold"
        ZSH_HIGHLIGHT_STYLES[builtin]="fg=blue,bold"
        ZSH_HIGHLIGHT_STYLES[alias]="fg=magenta,bold"
        ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=yellow"
        ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=yellow"
    '
fi

if command -v starship >/dev/null 2>&1; then
    STARSHIP_CACHE="$HOME/.cache/starship-init.zsh"
    STARSHIP_VERSION_FILE="$HOME/.cache/starship-version"
    if [[ ! -f "$STARSHIP_CACHE" || "$(starship --version)" != "$(cat "$STARSHIP_VERSION_FILE" 2>/dev/null)" ]]; then
        starship init zsh > "$STARSHIP_CACHE"
        starship --version > "$STARSHIP_VERSION_FILE"
    fi
    source "$STARSHIP_CACHE"
fi

if [[ -z "$FIRST_OPEN_SHELL" ]]; then
    export FIRST_OPEN_SHELL=1
    clear
    (fastfetch &) 2>/dev/null
fi
