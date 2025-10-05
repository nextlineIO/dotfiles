#!/usr/bin/env bash
set -euo pipefail

# === nm-helpers.sh ===
# Shared helpers for wifi-wofi.sh. Safe to source multiple times.

WIFI_WOFI_HOME="${WIFI_WOFI_HOME:-$HOME/.local/share/wifi-wofi}"
mkdir -p "$WIFI_WOFI_HOME/backups" "$WIFI_WOFI_HOME/logs"

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$WIFI_WOFI_HOME/logs/wifi-wofi.log"
}

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Wi‑Fi" "$*" || true
}

backup_conn() {
  local name="$1"
  local safe="$(echo "$name" | tr -cs '[:alnum:]._-' '_')"
  local out="$WIFI_WOFI_HOME/backups/${safe}-$(date +%Y%m%d-%H%M%S).nmconnection"
  if nmcli -g name,type con show | awk -F: '{print $1}' | grep -Fxq "$name"; then
    nmcli connection export "$name" "$out" && log "Backed up $name -> $out"
  fi
}

show_psk() {
  local name="$1"
  # This prints the PSK if stored by NM (may be blank if in keyring)
  nmcli -s -g 802-11-wireless-security.psk connection show "$name"
}

set_autojoin() {
  local name="$1"
  local onoff="$2" # yes|no
  backup_conn "$name"
  nmcli connection modify "$name" connection.autoconnect "$onoff"
  log "autojoin $name -> $onoff"
}

set_priority() {
  local name="$1"
  local prio="$2"
  backup_conn "$name"
  nmcli connection modify "$name" connection.autoconnect-priority "$prio"
  log "priority $name -> $prio"
}

set_dns_dhcp_only() {
  local name="$1"; shift
  local dns_list="$*"
  backup_conn "$name"
  nmcli connection modify "$name" ipv4.method auto ipv4.ignore-auto-dns yes ipv4.dns "$dns_list"
  nmcli connection up "$name" || true
  log "dns (dhcp-only) $name -> $dns_list"
}

set_dns_manual_ipv4() {
  local name="$1" ip="$2" prefix="$3" gw="$4" dns="$5"
  backup_conn "$name"
  nmcli connection modify "$name" ipv4.method manual ipv4.addresses "${ip}/${prefix}" ipv4.gateway "$gw" ipv4.dns "$dns"
  nmcli connection up "$name" || true
  log "manual ipv4 $name -> ${ip}/${prefix} gw=$gw dns=$dns"
}

set_dns_auto() {
  local name="$1"
  backup_conn "$name"
  nmcli connection modify "$name" ipv4.method auto ipv4.ignore-auto-dns no ipv4.dns ""
  nmcli connection up "$name" || true
  log "dns auto $name"
}

edit_password() {
  local name="$1" newpsk="$2"
  backup_conn "$name"
  nmcli connection modify "$name" 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$newpsk"
  log "password updated for $name"
}

bssid_lock() {
  local name="$1" bssid="$2"
  backup_conn "$name"
  nmcli connection modify "$name" 802-11-wireless.bssid "$bssid"
  log "bssid lock $name -> $bssid"
}

bssid_clear() {
  local name="$1"
  backup_conn "$name"
  nmcli connection modify "$name" 802-11-wireless.bssid ""
  log "bssid cleared $name"
}

# Load DNS presets from config
load_presets() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/wifi-wofi/dns-presets.conf"
  [ -f "$cfg" ] || return 0
  # Format: NAME=DNS1,DNS2,DNS3
  grep -v '^\s*$' "$cfg" | grep -v '^\s*#' | sed 's/\r$//' | while IFS='=' read -r k v; do
    [ -n "$k" ] && [ -n "$v" ] && printf '%s\t%s\n' "$k" "$v"
  done
} 
