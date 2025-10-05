# ~/.config/shell/prompt.sh
# Load from ~/.bashrc:
#   [ -f ~/.config/shell/prompt.sh ] && . ~/.config/shell/prompt.sh

# Only for interactive shells
[[ $- == *i* ]] || return

# ---------------- Colors for the static PS1 parts ----------------
# For static parts we can keep \[ \] safely.
CUSER='\[\e[38;2;0;234;255m\]'      # cyan (user)
CHOST='\[\e[38;2;255;42;109m\]'     # magenta (host)
CPATH='\[\e[38;2;130;170;255m\]'    # soft blue path
RST='\[\e[0m\]'

# Compact path depth in \w (2 = keep cwd + parent)
export PROMPT_DIRTRIM=2

# ---------------- Git segment (emits real ESC + \001/\002 markers) ---------------
# Because $(...) output isn’t parsed for \[ \], we must wrap non-printing
# sequences with \001 (start) and \002 (end) *in the output itself*.
__git_segment() {
  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --is-inside-work-tree &>/dev/null || return 0

  # Non-printing wrappers and colors for inside $(...)
  local SO=$'\001' EO=$'\002' ESC=$'\e'
  local C_CLEAN="${SO}${ESC}[38;2;80;250;123m${EO}"    # green
  local C_DIRTY="${SO}${ESC}[38;2;255;110;110m${EO}"   # coral
  local C_CONFL="${SO}${ESC}[38;2;255;85;85m${EO}"     # red
  local C_RST="${SO}${ESC}[0m${EO}"

  # Branch (or short SHA if detached)
  local b
  b="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo '?')"

  # Porcelain v2 status (fast, has upstream info)
  local st
  st="$(git status --porcelain=2 --branch 2>/dev/null)"

  # Flags (use grep -E to avoid bash-regex pitfalls)
  local staged='' dirty='' untracked='' stashed=''
  printf '%s\n' "$st" | grep -Eq '^[12] [A-Z]' && staged='+'
  printf '%s\n' "$st" | grep -Eq '^[12] .[A-Z]' && dirty='*'
  printf '%s\n' "$st" | grep -Eq '^\?\?'        && untracked='?'
  git rev-parse -q --verify refs/stash &>/dev/null && stashed='$'

  # Ahead/behind from header "# branch.ab +N -M"
  local ahead=0 behind=0 arrows="" ab
  if ab="$(printf '%s\n' "$st" | grep -m1 '^# branch\.ab ')" && [[ -n "$ab" ]]; then
    ahead="${ab#*+}";   ahead="${ahead%% *}"
    behind="${ab#*-}";  behind="${behind%% *}"
  fi
  (( ahead  > 0 )) && arrows+="↑${ahead}"
  (( behind > 0 )) && arrows+="${arrows:+ }↓${behind}"

  # Pick color based on state
  local C="$C_CLEAN"
  [[ -n "$dirty$untracked" ]] && C="$C_DIRTY"
  git diff --name-only --diff-filter=U --quiet 2>/dev/null || C="$C_CONFL"

  # Assemble: space + colored " branch [flags] [arrows]" + reset
  local flags="${staged}${dirty}${untracked}${stashed}"
  [[ -n "$flags"  ]] && flags=" ${flags}"
  [[ -n "$arrows" ]] && arrows=" ${arrows}"
  printf ' %s %s%s%s%s' "$C" "$b" "$flags" "$arrows" "$C_RST"
}

# ---------------- Final prompt -----------------------------------
# user@host /short/path (git) $
PS1="${CUSER}\u${RST}@${CHOST}\h${RST} ${CPATH}\w${RST}\$(__git_segment) \$ "

