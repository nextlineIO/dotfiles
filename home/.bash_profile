# Login shell shim: source XDG login config, then .bashrc for interactive shells
[ -f ~/.config/shell/bash_profile ] && . ~/.config/shell/bash_profile
[ -f ~/.bashrc ] && . ~/.bashrc
