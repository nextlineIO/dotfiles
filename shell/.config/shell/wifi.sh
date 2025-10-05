# WiFi Management Aliases & Help
# Loaded from ~/.config/shell/wifi.sh

# ── WiFi Aliases ────────────────────────────────────────────
alias wifi='nmcli device wifi list'
alias wifi-on='nmcli radio wifi on'
alias wifi-off='nmcli radio wifi off'
alias wifi-connect='nmcli device wifi connect'
alias wifi-status='nmcli connection show --active'
alias wifi-disconnect='nmcli connection down'
alias wifi-saved='nmcli connection show'
alias wifi-forget='nmcli connection delete'
alias wifi-scan='nmcli device wifi rescan && sleep 1 && nmcli device wifi list'
alias wifi-info='nmcli -f GENERAL,WIFI-PROPERTIES device show wlan0'

# ── WiFi Help Function ──────────────────────────────────────
wifi-help() {
    cat << 'HELP_EOF'
╔════════════════════════════════════════════════════════════╗
║              WiFi Management Commands                      ║
╚════════════════════════════════════════════════════════════╝

📡 BASIC COMMANDS
  wifi              List all available networks
  wifi-on           Turn WiFi on
  wifi-off          Turn WiFi off
  wifi-status       Show active connections
  wifi-scan         Rescan and list networks

🔌 CONNECTION COMMANDS  
  wifi-connect "SSID" [password "pass"]
                    Connect to a network
                    Example: wifi-connect "MyWiFi" password "mypass123"
                    Example: wifi-connect "OpenNetwork" (no password)
  
  wifi-disconnect "SSID"
                    Disconnect from a network
  
💾 SAVED NETWORKS
  wifi-saved        List all saved connections
  wifi-forget "SSID"
                    Forget/delete a saved network

ℹ️  INFORMATION
  wifi-info         Detailed WiFi adapter information
  wifi-help         Show this help menu

🎯 QUICK EXAMPLES
  # Connect to network with password
  wifi-connect "MyHomeWiFi" password "secretpass"
  
  # Connect to open network
  wifi-connect "Free_WiFi"
  
  # Disconnect from current network
  wifi-disconnect "MyHomeWiFi"
  
  # Forget a saved network
  wifi-forget "OldNetwork"

📱 GUI TOOLS
  wifi-manager      Launch wofi WiFi manager (Super+W)
  nm-applet         System tray applet
  nmtui             Terminal UI manager
  nm-connection-editor  
                    Full GUI connection editor

═══════════════════════════════════════════════════════════════
💡 TIP: Use Tab completion with network names!
HELP_EOF
}

# ── Advanced WiFi Functions ─────────────────────────────────

# Quick connect to most recent network
wifi-reconnect() {
    local last_network=$(nmcli -t -f NAME connection show --active | head -1)
    if [ -n "$last_network" ]; then
        echo "Reconnecting to: $last_network"
        nmcli connection up "$last_network"
    else
        echo "No recent network found. Use: wifi-connect \"SSID\""
    fi
}

# Show current WiFi password (requires sudo)
wifi-password() {
    if [ -z "$1" ]; then
        echo "Usage: wifi-password \"SSID\""
        return 1
    fi
    sudo grep -r "^psk=" /etc/NetworkManager/system-connections/"$1" 2>/dev/null | cut -d'=' -f2
}

# Show signal strength of current connection
wifi-signal() {
    nmcli -f IN-USE,SIGNAL,SSID device wifi list | grep "^\*" | awk '{print "Signal: " $2 "% - " $3}'
}

# Quick toggle WiFi on/off
wifi-toggle() {
    local status=$(nmcli radio wifi)
    if [ "$status" = "enabled" ]; then
        echo "Turning WiFi OFF..."
        nmcli radio wifi off
    else
        echo "Turning WiFi ON..."
        nmcli radio wifi on
    fi
}

# Show WiFi speed/link info
wifi-speed() {
    nmcli -f GENERAL.CONNECTION,GENERAL.DEVICE,IP4.ADDRESS,GENERAL.SPEED device show wlan0 2>/dev/null | grep -E "GENERAL|IP4|SPEED"
}
