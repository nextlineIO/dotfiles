# ~/.config/shell/aliases.sh

# --- Colors / LS_COLORS (pick one approach) -------------------------------

# A) vivid theme (modern, recommended)
if command -v vivid >/dev/null 2>&1; then
  export LS_COLORS="$(vivid generate molokai)"
else
  # B) fallback to dircolors if vivid not installed
  if command -v dircolors >/dev/null 2>&1; then
    # Use ~/.dircolors if present, else system default
    if [[ -r "$HOME/.dircolors" ]]; then
      eval "$(dircolors -b "$HOME/.dircolors")"
    else
      eval "$(dircolors -b)"
    fi
  fi
fi

# --- ls family -------------------------------------------------------------

alias ls='ls --color=auto --group-directories-first -F'
alias ll='ls -lah --color=auto --group-directories-first'
alias la='ls -A --color=auto --group-directories-first'
alias l='ls -CF --color=auto --group-directories-first'

# If you prefer eza (exa successor), swap these in instead:
# if command -v eza >/dev/null 2>&1; then
#   alias ls='eza --group-directories-first --icons --color=auto'
#   alias ll='eza -lah --group-directories-first --icons --color=auto'
#   alias la='eza -la --group-directories-first --icons --color=auto'
#   alias l='eza -1 --group-directories-first --icons --color=auto'
# fi

# --- grep family -----------------------------------------------------------

alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# --- navigation ------------------------------------------------------------

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# --- editors/launchers -----------------------------------------------------

alias v='nvim'
alias e='$EDITOR'

# --- safety / quality of life ---------------------------------------------

# Prompt once when deleting multiple files (safer than -i for every file)
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'

# Use your personal bin directory easily
export PATH="$HOME/bin:$PATH"

# --- git quickies ----------------------------------------------------------

alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gca='git commit -a'
alias gp='git push'
alias gl='git log --oneline --graph --decorate --all'

# --- system info -----------------------------------------------------------

alias dfh='df -h'
alias duh='du -sh * | sort -h'
alias psu='ps -eF | awk '"'"'{print $1,$2,$11}'"'"' | column -t'

# --- wofi/foot helpers (your setup) ---------------------------------------

alias wmenu='wofi --show drun'
alias footcfg='foot --config ~/.config/foot/foot.ini'

# End of aliases

