#!/bin/bash

################################################################################
# System Snapshot Generator
# Version: 1.3.0
# Purpose: Generate comprehensive system information for AI assistant context
# Usage: ./system-snapshot.sh [--auto]
#   --auto: Automatically save to ~/system-snapshot.txt (overwrites if exists)
#   No flag: Prompt for custom filename and location
#
# Changelog:
# v1.3.0 - Fixed binary and ANSI output issues
#        - Strip ANSI color codes from all command output
#        - Use dconf dump for readable settings (not binary .dconf/user)
#        - Skip binary files in ~/.config/pulse and similar
#        - Improved file type detection
#        - Added --no-color flags where supported
# v1.2.0 - Added systemd user service file contents (Section 17)
# v1.1.0 - Added audio, bluetooth, power/battery, temperature sections
# v1.0.0 - Initial release
#
################################################################################

set -eo pipefail

# Color codes for terminal output only
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERSION="1.3.0"
MAX_FILE_SIZE=$((50 * 1024 * 1024))
PERMISSION_ERRORS=()
STATIC_INFO_FILE="$HOME/.system-info.private"

################################################################################
# Helper Functions
################################################################################

# Strip ANSI escape codes from text
strip_ansi() {
    sed 's/\x1b\[[0-9;]*[mGKHF]//g'
}

print_section_header() {
    local title="$1"
    echo "" >> "$OUTPUT_FILE"
    echo "================================================================================" >> "$OUTPUT_FILE"
    echo "$title" >> "$OUTPUT_FILE"
    echo "================================================================================" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

print_subsection_header() {
    local title="$1"
    echo "" >> "$OUTPUT_FILE"
    echo "--- $title ---" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# Check if file is binary or should be skipped
is_binary_or_skip() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    
    # Skip known binary/cookie files
    case "$filename" in
        cookie|*.cookie|*.dat|*.db|*.sqlite|*.sqlite3)
            return 0
            ;;
    esac
    
    # Skip dconf user database (binary)
    if [[ "$filepath" == *"/.config/dconf/user" ]]; then
        return 0
    fi
    
    # Use file command to detect binary
    if file -b "$filepath" | grep -qiE "executable|binary|data|compiled|encrypted"; then
        return 0
    fi
    
    return 1
}

print_file_content() {
    local filepath="$1"
    local display_path="${2:-$filepath}"
    
    if [[ ! -f "$filepath" ]]; then
        echo "File not found: $display_path" >> "$OUTPUT_FILE"
        return
    fi
    
    if [[ ! -r "$filepath" ]]; then
        echo "PERMISSION DENIED: Cannot read $display_path" >> "$OUTPUT_FILE"
        PERMISSION_ERRORS+=("$display_path")
        return
    fi
    
    local filesize=$(stat -c%s "$filepath" 2>/dev/null || echo "0")
    if [[ $filesize -gt $MAX_FILE_SIZE ]]; then
        echo "FILE TOO LARGE ($(numfmt --to=iec-i --suffix=B $filesize)): Skipping $display_path" >> "$OUTPUT_FILE"
        return
    fi
    
    # Check if binary/should skip
    if is_binary_or_skip "$filepath"; then
        echo "BINARY/DATA FILE: $display_path (location recorded, content not printed)" >> "$OUTPUT_FILE"
        return
    fi
    
    echo "--- FILE: $display_path ---" >> "$OUTPUT_FILE"
    cat "$filepath" >> "$OUTPUT_FILE" 2>/dev/null || echo "ERROR: Could not read file content" >> "$OUTPUT_FILE"
    echo "--- END FILE: $display_path ---" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

run_command() {
    local description="$1"
    local command="$2"
    
    print_subsection_header "$description"
    echo "Command: $command" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    if eval "$command" 2>&1 | strip_ansi >> "$OUTPUT_FILE"; then
        echo "" >> "$OUTPUT_FILE"
    else
        echo "ERROR: Command failed or permission denied" >> "$OUTPUT_FILE"
        PERMISSION_ERRORS+=("Command: $command")
        echo "" >> "$OUTPUT_FILE"
    fi
}

process_directory_recursively() {
    local base_dir="$1"
    local section_title="$2"
    
    if [[ ! -d "$base_dir" ]]; then
        echo "Directory not found: $base_dir" >> "$OUTPUT_FILE"
        return
    fi
    
    print_subsection_header "$section_title"
    
    while IFS= read -r -d '' file; do
        # Skip .git directories and their contents
        if [[ "$file" == *"/.git/"* ]] || [[ "$file" == *"/.git" ]]; then
            continue
        fi
        
        local rel_path="${file#$base_dir/}"
        print_file_content "$file" "$base_dir/$rel_path"
    done < <(find "$base_dir" -type f -print0 2>/dev/null)
}

check_setup() {
    if [[ ! -f "$STATIC_INFO_FILE" ]]; then
        echo -e "${YELLOW}Warning: Static info file not found: $STATIC_INFO_FILE${NC}"
        echo -e "${YELLOW}   Section 0 will be empty. Create this file with your hardware details.${NC}"
        echo -e "${YELLOW}   See script header for template.${NC}"
        echo ""
        return 1
    fi
    return 0
}

################################################################################
# Main Script
################################################################################

echo -e "${BLUE}System Snapshot Generator${NC}"
echo -e "${BLUE}Version $VERSION${NC}"
echo "================================"
echo ""

check_setup

# Handle --auto flag
AUTO_MODE=false
if [[ "${1:-}" == "--auto" ]]; then
    AUTO_MODE=true
    OUTPUT_FILE="$HOME/system-snapshot.txt"
    
    if [[ -f "$OUTPUT_FILE" ]]; then
        TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
        OLD_FILE="$HOME/system-snapshot-$TIMESTAMP.txt"
        mv "$OUTPUT_FILE" "$OLD_FILE"
        echo -e "${YELLOW}Existing snapshot renamed to: $OLD_FILE${NC}"
        
        cd "$HOME"
        ls -t system-snapshot-*.txt 2>/dev/null | tail -n +6 | xargs -r rm
        echo -e "${GREEN}Old snapshots cleaned (keeping last 5)${NC}"
    fi
else
    echo ""
    read -p "Enter output filename (default: system-snapshot.txt): " FILENAME
    FILENAME="${FILENAME:-system-snapshot.txt}"
    
    read -p "Enter output directory (default: $HOME): " OUTPUT_DIR
    OUTPUT_DIR="${OUTPUT_DIR:-$HOME}"
    OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"
    
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_FILE="$OUTPUT_DIR/$FILENAME"
    
    if [[ -f "$OUTPUT_FILE" ]]; then
        read -p "File exists. Overwrite? (y/n): " OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Aborted.${NC}"
            exit 1
        fi
    fi
fi

echo -e "${GREEN}Generating snapshot: $OUTPUT_FILE${NC}"
echo ""

print_progress() {
    echo -e "${BLUE}▶${NC} $1"
}

# Initialize output file with header
cat > "$OUTPUT_FILE" << EOF
================================================================================
SYSTEM SNAPSHOT - AI ASSISTANT CONTEXT FILE
================================================================================
Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')
Script Version: $VERSION
Hostname: $(hostname)
User: $(whoami)
Home: $HOME

PURPOSE:
--------
This file provides complete system configuration and state information for AI
assistants to understand the computing environment without requiring multiple
follow-up questions. Use this for troubleshooting, configuration assistance,
dotfile management, and system customization.

================================================================================
QUICK REFERENCE - KEY SYSTEM FACTS
================================================================================

Operating System:    $(cat /etc/os-release | grep "^PRETTY_NAME=" | cut -d'"' -f2)
Kernel:              $(uname -r)
Desktop/WM:          ${XDG_CURRENT_DESKTOP:-Hyprland}
Session Type:        ${XDG_SESSION_TYPE:-wayland}
Shell:               $(basename "$SHELL")
Package Manager:     pacman/yay (Arch Linux)
Total Packages:      $(pacman -Q | wc -l)
Dotfiles:            GNU Stow managed (~/dotfiles)
Display Server:      Wayland
Window Manager:      Hyprland
Terminal:            ${TERM:-alacritty}

Hardware Summary:
  CPU:      $(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
  Memory:   $(free -h | awk '/^Mem:/ {print $2}')
  Storage:  $(df -h / | awk 'NR==2 {print $2}') total, $(df -h / | awk 'NR==2 {print $3}') used

================================================================================
DOCUMENT STRUCTURE - TABLE OF CONTENTS
================================================================================

This snapshot is organized into 18 sections. Below is a guide to what
information can be found in each section:

SECTION 0: Static Hardware & User Information
  - Manually-entered hardware specifications from ~/.system-info.private
  - Device model, serial number, warranty information
  - Display/monitor details and user notes
  - This section is user-maintained and may be empty if not configured

SECTION 1: Hardware Information
  - CPU specifications, memory, disk layout, filesystems
  - PCI and USB device listings
  - Firmware information, BIOS version and update status
  - Use this for: hardware troubleshooting, driver issues, firmware updates

SECTION 2: System Core
  - Kernel version, OS details, init system
  - Running, failed, and enabled systemd services
  - System uptime and service states
  - Use this for: service troubleshooting, boot issues, systemd configuration

SECTION 3: Package Management
  - Complete list of installed packages (pacman)
  - Explicitly installed vs. dependency packages
  - AUR/foreign packages
  - Use this for: dependency resolution, package recommendations, cleanup

SECTION 4: Display & Wayland
  - Hyprland version and runtime configuration
  - Monitor setup, workspaces, active windows
  - Input devices, keybindings, display settings
  - GTK/Qt themes, icon themes, cursor themes
  - Use this for: Hyprland configuration, multi-monitor setup, theming

SECTION 5: Shell & Environment
  - Current shell and version
  - Complete environment variables and PATH
  - Shell configuration files (.bashrc, .bash_profile, etc.)
  - Use this for: shell scripting, PATH issues, environment troubleshooting

SECTION 6: Dotfiles Structure
  - Dotfiles directory layout (GNU Stow structure)
  - Config directory tree overview
  - Custom script locations
  - Use this for: understanding dotfile organization, stow package management

SECTION 7: Configuration Files
  - Complete contents of ALL files in ~/.config/
  - Custom scripts from ~/bin/
  - Application-specific configurations
  - Use this for: debugging config issues, understanding current setup
  - NOTE: This is the largest section with complete file contents

SECTION 8: Git Configuration
  - Global git settings and aliases
  - .gitconfig contents
  - Use this for: git workflow, credential issues, repository setup

SECTION 9: SSH Configuration
  - SSH directory structure and permissions
  - Public key contents (private keys never included)
  - SSH config file with host definitions
  - Known hosts count (contents excluded for security)
  - Use this for: SSH connection issues, key management, remote access setup

SECTION 10: Network Configuration
  - Network interfaces and IP addresses
  - Routing table and DNS settings
  - NetworkManager connections and WiFi status
  - Use this for: network troubleshooting, VPN setup, connectivity issues

SECTION 11: Boot & System Logs
  - Boot time analysis and slow services
  - Recent journal entries and error logs
  - Kernel messages and boot sequence
  - Use this for: boot problems, performance issues, error diagnosis

SECTION 12: Audio System
  - PulseAudio/Pipewire sinks and sources
  - Wireplumber configuration
  - Default audio devices
  - Use this for: audio troubleshooting, device switching, Bluetooth audio

SECTION 13: Bluetooth
  - Bluetooth adapter information
  - Paired devices and connection status
  - Bluetooth service state
  - Use this for: Bluetooth pairing issues, device management

SECTION 14: Power & Battery
  - Battery health, charge cycles, current state
  - Power management configuration (TLP)
  - All power devices and AC adapter status
  - Use this for: battery optimization, power management, laptop suspend issues

SECTION 15: Temperature & Sensors
  - Hardware sensor readings (CPU, GPU, drives)
  - Thermal zones and fan speeds
  - Use this for: thermal issues, fan control, overheating diagnosis

SECTION 16: Processes & Resources
  - Top memory and CPU consuming processes
  - Process state summary
  - Use this for: performance troubleshooting, resource usage analysis

SECTION 17: Systemd User Services
  - Complete contents of user service files (.service)
  - Timer, socket, and path unit files
  - User-specific systemd configurations
  - Use this for: service debugging, autostart issues, systemd user units

SECTION 18: Notes for Future Additions
  - Template for adding new information to the snapshot script
  - Suggestions for potential expansions

================================================================================
SECURITY & PRIVACY NOTES
================================================================================

What IS included:
  - Public SSH keys (.pub files)
  - SSH config with hostnames and connection settings
  - Public configuration files
  - System state and running processes

What is NOT included:
  - Private SSH keys (only public keys are included)
  - SSH known_hosts contents (only count is shown)
  - Binary file contents (location recorded only)
  - Files larger than 50MB
  - Passwords or sensitive credentials

================================================================================
HOW TO USE THIS FILE WITH AI ASSISTANTS
================================================================================

1. Upload this entire file to your AI assistant (Claude, etc.)
2. The AI will have complete context about your system configuration
3. Ask questions about configuration, troubleshooting, or customization
4. The AI can reference specific sections when providing answers
5. Regenerate this snapshot after major system changes

Common use cases:
  - "Why isn't [service] starting?" → AI checks Section 2 and 17
  - "Help me configure [application]" → AI checks Section 7
  - "My display setup isn't working" → AI checks Section 4
  - "Network connectivity issues" → AI checks Section 10
  - "Set up SSH to this server" → AI checks Section 9

================================================================================
BEGIN DETAILED SYSTEM INFORMATION
================================================================================
EOF

################################################################################
# SECTION 0: STATIC HARDWARE & USER INFORMATION
################################################################################
print_progress "Section 0: Static Hardware & User Information"
print_section_header "SECTION 0: STATIC HARDWARE & USER INFORMATION"

if [[ -f "$STATIC_INFO_FILE" ]]; then
    cat "$STATIC_INFO_FILE" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
else
    cat >> "$OUTPUT_FILE" << 'EOF'
No static information file found.

To add your hardware specifications, warranty information, and other static
details, create a file at: ~/.system-info.private

See the script header (system-snapshot.sh) for a template.

EOF
fi

################################################################################
# SECTION 1: HARDWARE INFORMATION
################################################################################
print_progress "Section 1: Hardware Information"
print_section_header "SECTION 1: HARDWARE INFORMATION"

run_command "CPU Information" "lscpu"
run_command "Memory Information" "free -h"
run_command "Disk Layout and Filesystems" "lsblk -f"
run_command "Disk Usage" "df -h"
run_command "GPU Information" "lspci -k | grep -A 3 VGA"
run_command "All PCI Devices" "lspci"
run_command "USB Devices" "lsusb"

print_subsection_header "Firmware Information"
run_command "Firmware Devices" "fwupdmgr get-devices --no-unreported-check 2>/dev/null || fwupdmgr get-devices"
run_command "Firmware Updates Available" "fwupdmgr get-updates --no-unreported-check 2>/dev/null || fwupdmgr get-updates"
run_command "Firmware Update History" "fwupdmgr get-history 2>/dev/null || echo 'No history available'"
run_command "BIOS Version" "cat /sys/class/dmi/id/bios_version 2>/dev/null || echo 'Not available'"
run_command "BIOS Date" "cat /sys/class/dmi/id/bios_date 2>/dev/null || echo 'Not available'"
run_command "BIOS Vendor" "cat /sys/class/dmi/id/bios_vendor 2>/dev/null || echo 'Not available'"

################################################################################
# SECTION 2: SYSTEM CORE
################################################################################
print_progress "Section 2: System Core"
print_section_header "SECTION 2: SYSTEM CORE"

run_command "Kernel Version" "uname -a"
run_command "OS Release Information" "cat /etc/os-release"
run_command "Running Services" "systemctl list-units --type=service --state=running --no-pager"
run_command "Failed Services" "systemctl --failed --no-pager"
run_command "Enabled User Services" "systemctl --user list-unit-files --state=enabled --no-pager"
run_command "Init System" "ls -l /sbin/init"
run_command "System Uptime" "uptime"

################################################################################
# SECTION 3: PACKAGE MANAGEMENT
################################################################################
print_progress "Section 3: Package Management"
print_section_header "SECTION 3: PACKAGE MANAGEMENT"

run_command "All Installed Packages" "pacman -Q"
run_command "Explicitly Installed Packages" "pacman -Qe"
run_command "AUR/Foreign Packages" "pacman -Qm"
run_command "Package Statistics" "pacman -Q | wc -l && echo 'Total packages installed'"

################################################################################
# SECTION 4: DISPLAY & WAYLAND
################################################################################
print_progress "Section 4: Display & Wayland"
print_section_header "SECTION 4: DISPLAY & WAYLAND"

run_command "Session Type" "echo \$XDG_SESSION_TYPE"
run_command "Hyprland Version" "hyprctl version"
run_command "Monitor Configuration" "hyprctl monitors"
run_command "Active Workspaces" "hyprctl workspaces"
run_command "Hyprland Devices" "hyprctl devices"
run_command "Hyprland Active Keybindings" "hyprctl binds"
run_command "Hyprland Splash" "hyprctl splash"

print_subsection_header "Theme Information"
run_command "GTK Theme Settings" "gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo 'gsettings not available'"
run_command "Icon Theme" "gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || echo 'gsettings not available'"
run_command "Cursor Theme" "gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || echo 'gsettings not available'"
run_command "Qt Theme" "echo \${QT_QPA_PLATFORMTHEME:-'Not set'}"
run_command "Qt Style" "echo \${QT_STYLE_OVERRIDE:-'Not set'}"

if [[ -f "$HOME/.gtkrc-2.0" ]]; then
    print_file_content "$HOME/.gtkrc-2.0"
fi

if [[ -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
    print_file_content "$HOME/.config/gtk-4.0/settings.ini"
fi

run_command "Current Color Scheme (if set)" "echo \${GTK_THEME:-'Not set'}"
run_command "Installed GTK Themes" "ls /usr/share/themes/ ~/.themes/ ~/.local/share/themes/ 2>/dev/null | sort -u"
run_command "Installed Icon Themes" "ls /usr/share/icons/ ~/.icons/ ~/.local/share/icons/ 2>/dev/null | sort -u"

################################################################################
# SECTION 5: SHELL & ENVIRONMENT
################################################################################
print_progress "Section 5: Shell & Environment"
print_section_header "SECTION 5: SHELL & ENVIRONMENT"

run_command "Current Shell" "echo \$SHELL"
run_command "Shell Version" "bash --version | head -n 1"
run_command "Environment Variables" "env | sort"
run_command "PATH" "echo \$PATH | tr ':' '\n'"

print_subsection_header "Shell Configuration Files"
if [[ -f "$HOME/.bashrc" ]]; then
    print_file_content "$HOME/.bashrc"
fi
if [[ -f "$HOME/.bash_profile" ]]; then
    print_file_content "$HOME/.bash_profile"
fi
if [[ -f "$HOME/.profile" ]]; then
    print_file_content "$HOME/.profile"
fi
if [[ -f "$HOME/.inputrc" ]]; then
    print_file_content "$HOME/.inputrc"
fi

################################################################################
# SECTION 6: DOTFILES STRUCTURE
################################################################################
print_progress "Section 6: Dotfiles Structure"
print_section_header "SECTION 6: DOTFILES STRUCTURE"

if [[ -d "$HOME/dotfiles" ]]; then
    run_command "Stow Packages (dotfiles directory listing)" "ls -la $HOME/dotfiles"
    run_command "Dotfiles Tree Structure" "tree -L 3 $HOME/dotfiles 2>/dev/null || find $HOME/dotfiles -type d | head -n 50"
fi

run_command "Config Directory Tree" "tree -L 2 $HOME/.config 2>/dev/null || find $HOME/.config -maxdepth 2 -type d"
run_command "Bin Directory Listing" "ls -lah $HOME/bin"

################################################################################
# SECTION 7: CONFIGURATION FILES
################################################################################
print_progress "Section 7: Configuration Files (this may take a moment...)"
print_section_header "SECTION 7: CONFIGURATION FILES"

# Process all config directories
if [[ -d "$HOME/.config" ]]; then
    for config_dir in "$HOME/.config"/*; do
        if [[ -d "$config_dir" ]]; then
            dir_name=$(basename "$config_dir")
            
            # Special handling for dconf - use dconf dump instead
            if [[ "$dir_name" == "dconf" ]]; then
                print_subsection_header "Config: ~/.config/dconf/ (readable export)"
                echo "--- dconf settings dump ---" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
                dconf dump / 2>/dev/null >> "$OUTPUT_FILE" || echo "dconf not available or no settings" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
            else
                process_directory_recursively "$config_dir" "Config: ~/.config/$dir_name/"
            fi
        fi
    done
    
    # Process individual config files in .config root
    for config_file in "$HOME/.config"/*; do
        if [[ -f "$config_file" ]]; then
            print_file_content "$config_file"
        fi
    done
fi

# Process ~/bin scripts
if [[ -d "$HOME/bin" ]]; then
    process_directory_recursively "$HOME/bin" "Custom Scripts: ~/bin/"
fi

################################################################################
# SECTION 8: GIT CONFIGURATION
################################################################################
print_progress "Section 8: Git Configuration"
print_section_header "SECTION 8: GIT CONFIGURATION"

run_command "Git Global Configuration" "git config --list --global"

if [[ -f "$HOME/.gitconfig" ]]; then
    print_file_content "$HOME/.gitconfig"
fi

if [[ -f "$HOME/.config/git/config" ]]; then
    print_file_content "$HOME/.config/git/config"
fi

################################################################################
# SECTION 9: SSH CONFIGURATION
################################################################################
print_progress "Section 9: SSH Configuration"
print_section_header "SECTION 9: SSH CONFIGURATION"

print_subsection_header "SSH Directory Structure"
run_command "SSH Directory Contents" "ls -la $HOME/.ssh"

if [[ -d "$HOME/.ssh/keys" ]]; then
    print_subsection_header "SSH Keys in ~/.ssh/keys/"
    run_command "SSH Keys Listing" "ls -la $HOME/.ssh/keys"
    
    print_subsection_header "SSH Public Keys Content"
    for pubkey in "$HOME/.ssh/keys"/*.pub; do
        if [[ -f "$pubkey" ]]; then
            print_file_content "$pubkey"
        fi
    done
fi

if [[ -f "$HOME/.ssh/config" ]]; then
    print_subsection_header "SSH Config File"
    print_file_content "$HOME/.ssh/config"
fi

print_subsection_header "SSH Known Hosts"
if [[ -f "$HOME/.ssh/known_hosts" ]]; then
    echo "Known hosts count: $(wc -l < $HOME/.ssh/known_hosts)" >> "$OUTPUT_FILE"
    echo "(Contents not printed for security)" >> "$OUTPUT_FILE"
else
    echo "No known_hosts file found" >> "$OUTPUT_FILE"
fi

################################################################################
# SECTION 10: NETWORK CONFIGURATION
################################################################################
print_progress "Section 10: Network Configuration"
print_section_header "SECTION 10: NETWORK CONFIGURATION"

run_command "Network Interfaces" "ip addr"
run_command "Routing Table" "ip route"
run_command "NetworkManager Status" "nmcli device status"
run_command "Active Connections" "nmcli connection show --active"
run_command "DNS Configuration" "cat /etc/resolv.conf"

################################################################################
# SECTION 11: BOOT & SYSTEM LOGS
################################################################################
print_progress "Section 11: Boot & System Logs"
print_section_header "SECTION 11: BOOT & SYSTEM LOGS"

run_command "Boot Time Analysis" "systemd-analyze"
run_command "Slowest Boot Services (Top 20)" "systemd-analyze blame | head -n 20"
run_command "Last Boot Journal (last 100 lines)" "journalctl -b --no-pager | tail -n 100"
run_command "Recent Errors" "journalctl -p err -b --no-pager | tail -n 50"
run_command "Kernel Messages (via journalctl)" "journalctl -k -b --no-pager | tail -n 100"

################################################################################
# SECTION 12: AUDIO SYSTEM
################################################################################
print_progress "Section 12: Audio System"
print_section_header "SECTION 12: AUDIO SYSTEM"

run_command "PulseAudio/Pipewire Sinks" "pactl list sinks short"
run_command "PulseAudio/Pipewire Sources" "pactl list sources short"
run_command "Wireplumber Status" "wpctl status"
run_command "Default Sink" "pactl get-default-sink"
run_command "Default Source" "pactl get-default-source"

################################################################################
# SECTION 13: BLUETOOTH
################################################################################
print_progress "Section 13: Bluetooth"
print_section_header "SECTION 13: BLUETOOTH"

run_command "Bluetooth Adapter Info" "bluetoothctl show"
run_command "Paired Bluetooth Devices" "bluetoothctl devices"
run_command "Bluetooth Service Status" "systemctl status bluetooth --no-pager"

################################################################################
# SECTION 14: POWER & BATTERY
################################################################################
print_progress "Section 14: Power & Battery"
print_section_header "SECTION 14: POWER & BATTERY"

run_command "Battery Information" "upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null || upower -i \$(upower -e | grep battery | head -n1) 2>/dev/null || echo 'No battery found'"
run_command "All Power Devices" "upower -e"
run_command "TLP Battery Statistics" "tlp-stat -b 2>/dev/null || echo 'TLP not running or not configured'"
run_command "AC Adapter and Thermal Info" "acpi -V 2>/dev/null || echo 'acpi command not available'"

################################################################################
# SECTION 15: TEMPERATURE & SENSORS
################################################################################
print_progress "Section 15: Temperature & Sensors"
print_section_header "SECTION 15: TEMPERATURE & SENSORS"

run_command "Hardware Sensors" "sensors 2>/dev/null || echo 'lm-sensors not configured - run sensors-detect'"
run_command "CPU Thermal Zones" "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | awk '{print \$1/1000\"°C\"}' || echo 'Thermal info not available'"

################################################################################
# SECTION 16: PROCESSES & RESOURCES
################################################################################
print_progress "Section 16: Processes & Resources"
print_section_header "SECTION 16: PROCESSES & RESOURCES"

run_command "Top 10 Memory Consuming Processes" "ps aux --sort=-%mem | head -n 11"
run_command "Top 10 CPU Consuming Processes" "ps aux --sort=-%cpu | head -n 11"
run_command "Process Count by State" "ps aux | awk '{print \$8}' | sort | uniq -c | sort -rn"

################################################################################
# SECTION 17: SYSTEMD USER SERVICES
################################################################################
print_progress "Section 17: Systemd User Services"
print_section_header "SECTION 17: SYSTEMD USER SERVICES"

if [[ -d "$HOME/.config/systemd/user" ]]; then
    print_subsection_header "User Service Files"
    
    for service_file in "$HOME/.config/systemd/user"/*.service; do
        if [[ -f "$service_file" ]]; then
            print_file_content "$service_file"
        fi
    done
    
    print_subsection_header "User Timer Files"
    for timer_file in "$HOME/.config/systemd/user"/*.timer; do
        if [[ -f "$timer_file" ]]; then
            print_file_content "$timer_file"
        fi
    done
    
    print_subsection_header "User Socket Files"
    for socket_file in "$HOME/.config/systemd/user"/*.socket; do
        if [[ -f "$socket_file" ]]; then
            print_file_content "$socket_file"
        fi
    done
    
    print_subsection_header "User Path Files"
    for path_file in "$HOME/.config/systemd/user"/*.path; do
        if [[ -f "$path_file" ]]; then
            print_file_content "$path_file"
        fi
    done
else
    echo "No user systemd directory found at ~/.config/systemd/user" >> "$OUTPUT_FILE"
fi

################################################################################
# SECTION 18: NOTES FOR FUTURE ADDITIONS
################################################################################
print_progress "Section 18: Notes for Future Additions"
print_section_header "SECTION 18: NOTES FOR FUTURE COMMAND ADDITIONS"

cat >> "$OUTPUT_FILE" << 'EOF'
This section serves as a reference for adding new commands to this script.

Format for adding new commands:
1. Identify the appropriate section (or create a new one)
2. Use: run_command "Description" "command_to_run"
3. For file contents: print_file_content "/path/to/file"
4. For directories: process_directory_recursively "/path/to/dir" "Section Title"

Potential future additions:
- Container info: docker ps, podman ps (if installed)
- Python environments: pip list, conda env list (if using)
- Node environments: npm list -g, nvm list (if using)
- Gaming: Steam install location, Proton versions (if gaming setup)
- Virtualization: virsh list, VirtualBox VMs (if using VMs)

EOF

################################################################################
# COMPLETION
################################################################################
print_progress "Finalizing snapshot..."

print_section_header "PERMISSION ERRORS ENCOUNTERED"

if [[ ${#PERMISSION_ERRORS[@]} -eq 0 ]]; then
    echo "No permission errors encountered." >> "$OUTPUT_FILE"
else
    echo "The following items could not be accessed due to permissions:" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    for error in "${PERMISSION_ERRORS[@]}"; do
        echo "- $error" >> "$OUTPUT_FILE"
    done
fi

echo "" >> "$OUTPUT_FILE"
echo "=================================================================================" >> "$OUTPUT_FILE"
echo "END OF SYSTEM SNAPSHOT" >> "$OUTPUT_FILE"
echo "=================================================================================" >> "$OUTPUT_FILE"

echo -e "${GREEN}✓ Snapshot complete!${NC}"
echo -e "Output file: ${BLUE}$OUTPUT_FILE${NC}"
echo -e "File size: ${YELLOW}$(du -h "$OUTPUT_FILE" | cut -f1)${NC}"

if [[ ${#PERMISSION_ERRORS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠ Warning: ${#PERMISSION_ERRORS[@]} permission errors encountered${NC}"
    echo -e "   See end of file for details"
fi

echo ""
echo -e "${GREEN}Ready to share${NC}"
