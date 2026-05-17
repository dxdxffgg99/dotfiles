ZSH_THEME="agnoster"
source ~/.oh-my-zsh/oh-my-zsh.sh

clear
fastfetch

alias la='ls -lha'
alias reload='source ~/.zshrc'
alias cls='clear'
alias cd..='cd ..'

FNM_PATH="/home/kr0/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi

export PATH="$PATH:/home/kr0/.lmstudio/bin"