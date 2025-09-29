#!/usr/bin/env bash
set -euo pipefail

# Robust Hyprland layout toggle between 'master' and 'dwindle'.
# Strategy: prefer `hyprctl getoption general:layout` (current authoritative value);
# fallback to activeworkspace output (JSON or plain).
get_layout() {
  # Try getoption first
  if out="$(hyprctl getoption general:layout 2>/dev/null)"; then
    # Typical output contains a line like: "str: dwindle"
    if lay="$(printf "%s" "$out" | sed -n 's/.*str:\s*//p' | head -n1)"; then
      lay="$(printf "%s" "$lay" | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n')"
      if [ -n "$lay" ]; then
        printf "%s\n" "$lay"
        return 0
      fi
    fi
  fi

  # Fallback: JSON
  if out="$(hyprctl activeworkspace -j 2>/dev/null)"; then
    if lay="$(printf "%s" "$out" | jq -r '.layout' 2>/dev/null)"; then
      lay="$(printf "%s" "$lay" | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n')"
      if [ -n "$lay" ] && [ "$lay" != "null" ]; then
        printf "%s\n" "$lay"
        return 0
      fi
    fi
  fi

  # Last resort: plain text parsing
  if out="$(hyprctl activeworkspace 2>/dev/null)"; then
    if lay="$(printf "%s" "$out" | sed -n 's/^layout:\s*//p' | head -n1)"; then
      lay="$(printf "%s" "$lay" | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n')"
      if [ -n "$lay" ]; then
        printf "%s\n" "$lay"
        return 0
      fi
    fi
  fi

  printf "unknown\n"
  return 1
}

layout="$(get_layout || true)"
case "$layout" in
  master)  hyprctl keyword general:layout dwindle ;;
  dwindle) hyprctl keyword general:layout master  ;;
  *)       hyprctl keyword general:layout master  ;;  # sane default
esac
