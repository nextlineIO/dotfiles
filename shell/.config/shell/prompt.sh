# Only for interactive shells
[[ $- == *i* ]] || return

# Color escapes wrapped in \[ \] so readline keeps cursor math correct
CUSER='\[\e[38;2;0;234;255m\]'     # cyan  #00EAFF
CHOST='\[\e[38;2;255;42;109m\]'    # magenta #FF2A6D
CPATH='\[\e[38;2;255;203;107m\]'   # amber  #FFCB6B
__r='\[\e[0m\]'                    # reset

# Optional: shorten deep paths
export PROMPT_DIRTRIM=2

# Your chosen one-line prompt
PS1="${CUSER}\u${__r}@${CHOST}\h${__r} ${CPATH}\w${__r} \$ "

