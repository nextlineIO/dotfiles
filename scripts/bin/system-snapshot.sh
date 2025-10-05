#!/bin/bash

################################################################################
# System Snapshot Generator
# Purpose: Generate comprehensive system information for AI assistant context
# Usage: ./system-snapshot.sh [--auto]
#   --auto: Automatically save to ~/system-snapshot.txt (overwrites if exists)
#   No flag: Prompt for custom filename and location
#
# SETUP INSTRUCTIONS:
# 1. Place this script in ~/bin/system-snapshot.sh
# 2. Make executable: chmod +x ~/bin/system-snapshot.sh
# 3. Create ~/.system-info.private with your static hardware details (see template below)
# 4. Add .system-info.private to git's global exclude file:
#    echo ".system-info.private" >> ~/.config/git/ignore
# 5. Add to .gitignore (if using dotfiles repo):
#    echo "system-snapshot*.txt" >> ~/dotfiles/.gitignore
# 6. Run: system-snapshot.sh --auto
#
# TEMPLATE FOR ~/.system-info.private:
# Create this file in your home directory with your specific information.
# The .private extension ensures it's never accidentally committed!
#
# cat > ~/.system-info << 'EOF'
# === Hardware Specifications ===
#
# Device: [Your laptop/desktop model]
# Model: [Model number]
# Screen: [Screen size and resolution]
# Processor: [CPU model]
# Storage: [Storage capacity and type]
# Memory: [RAM amount]
# Serial Number: [Serial number]
#
# === Warranty Information ===
#
# Status: [Warranty status]
# Coverage Through: [Date]
# Warranty Portal: [URL to warranty page]
#
# === Display Information ===
#
# External Monitor: [Monitor model if applicable]
# Monitor Resolution: [Resolution]
# Monitor Connection: [Connection type]
#
# === User Notes ===
#
# [Any additional static information you want to include]
#
# EOF
#
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Maximum file size to include (50MB in bytes)
MAX_FILE_SIZE=$((50 * 1024 * 1024))

# Track permission errors
PERMISSION_ERRORS=()

# Static info file location
STATIC_INFO_FILE="$HOME/.system-info.private"

################################################################################
# Helper Functions
################################################################################

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

print_file_content() {
    local filepath="$1"
    local display_path="${2:-$filepath}"
    
    # Check if file exists
    if [[ ! -f "$filepath" ]]; then
        echo "File not found: $display_path" >> "$OUTPUT_FILE"
        return
    fi
    
    # Check if we have read permission
    if [[ ! -r "$filepath" ]]; then
        echo "PERMISSION DENIED: Cannot read $display_path" >> "$OUTPUT_FILE"
        PERMISSION_ERRORS+=("$display_path")
        return
    fi
    
    # Check file size
    local filesize=$(stat -c%s "$filepath" 2>/dev/null || echo "0")
    if [[ $filesize -gt $MAX_FILE_SIZE ]]; then
        echo "FILE TOO LARGE ($(numfmt --to=iec-i --suffix=B $filesize)): Skipping $display_path" >> "$OUTPUT_FILE"
        return
    fi
    
    # Check if binary
    if file "$filepath" | grep -q "executable\|binary"; then
        echo "BINARY FILE: $display_path (location recorded, content not printed)" >> "$OUTPUT_FILE"
        return
    fi
    
    # Print the file
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
    
    if eval "$command" >> "$OUTPUT_FILE" 2>&1; then
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
    
    # Use find to get all files recursively
    while IFS= read -r -d '' file; do
        # Skip .git directories and their contents
        if [[ "$file" == *"/.git/"* ]] || [[ "$file" == *"/.git" ]]; then
            continue
        fi
        
        # Get relative path for cleaner output
        local rel_path="${file#$base_dir/}"
        print_file_content "$file" "$base_dir/$rel_path"
    done < <(find "$base_dir" -type f -print0 2>/dev/null)
}

check_setup() {
    if [[ ! -f "$STATIC_INFO_FILE" ]]; then
        echo -e "${YELLOW}⚠ Warning: Static info file not found: $STATIC_INFO_FILE${NC}"
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
echo "================================"
echo ""

# Check for static info file
check_setup

# Handle --auto flag
AUTO_MODE=false
if [[ "${1:-}" == "--auto" ]]; then
    AUTO_MODE=true
    OUTPUT_FILE="$HOME/system-snapshot.txt"
    
    # If file exists, rename it with timestamp
    if [[ -f "$OUTPUT_FILE" ]]; then
        TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
        OLD_FILE="$HOME/system-snapshot-$TIMESTAMP.txt"
        mv "$OUTPUT_FILE" "$OLD_FILE"
        echo -e "${YELLOW}Existing snapshot renamed to: $OLD_FILE${NC}"
        
        # Keep only last 5 snapshots
        cd "$HOME"
        ls -t system-snapshot-*.txt 2>/dev/null | tail -n +6 | xargs -r rm
        echo -e "${GREEN}Old snapshots cleaned (keeping last 5)${NC}"
    fi
else
    # Interactive mode - prompt for filename and location
    echo ""
    read -p "Enter output filename (default: system-snapshot.txt): " FILENAME
    FILENAME="${FILENAME:-system-snapshot.txt}"
    
    read -p "Enter output directory (default: $HOME): " OUTPUT_DIR
    OUTPUT_DIR="${OUTPUT_DIR:-$HOME}"
    
    # Expand tilde if present
    OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"
    
    # Create directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"
    
    OUTPUT_FILE="$OUTPUT_DIR/$FILENAME"
    
    # Warn if file exists
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

# Initialize output file
cat > "$OUTPUT_FILE" << EOF
================================================================================
SYSTEM SNAPSHOT
================================================================================
Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')
Hostname: $(hostname)
User: $(whoami)
Home: $HOME

Purpose: This file provides comprehensive system information for AI assistant
         context in troubleshooting, customization, and development tasks.

================================================================================
EOF

################################################################################
# SECTION 0: STATIC HARDWARE & USER INFORMATION
################################################################################
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
print_section_header "SECTION 1: HARDWARE INFORMATION"

run_command "CPU Information" "lscpu"
run_command "Memory Information" "free -h"
run_command "Disk Layout and Filesystems" "lsblk -f"
run_command "Disk Usage" "df -h"
run_command "GPU Information" "lspci -k | grep -A 3 VGA"
run_command "All PCI Devices" "lspci"
run_command "USB Devices" "lsusb"

print_subsection_header "Firmware Information"
run_command "Firmware Devices" "fwupdmgr get-devices"
run_command "Firmware Updates Available" "fwupdmgr get-updates"
run_command "Firmware Update History" "fwupdmgr get-history"
run_command "BIOS/UEFI Information" "dmidecode -t bios 2>/dev/null || echo 'dmidecode requires root access'"

################################################################################
# SECTION 2: SYSTEM CORE
################################################################################
print_section_header "SECTION 2: SYSTEM CORE"

run_command "Kernel Version" "uname -a"
run_command "OS Release Information" "cat /etc/os-release"
run_command "Running Services" "systemctl list-units --type=service --state=running"
run_command "Failed Services" "systemctl --failed"
run_command "Enabled User Services" "systemctl --user list-unit-files --state=enabled"
run_command "Init System" "ls -l /sbin/init"
run_command "System Uptime" "uptime"

################################################################################
# SECTION 3: PACKAGE MANAGEMENT
################################################################################
print_section_header "SECTION 3: PACKAGE MANAGEMENT"

run_command "All Installed Packages" "pacman -Q"
run_command "Explicitly Installed Packages" "pacman -Qe"
run_command "AUR/Foreign Packages" "pacman -Qm"
run_command "Package Statistics" "pacman -Q | wc -l && echo 'Total packages installed'"

################################################################################
# SECTION 4: DISPLAY & WAYLAND
################################################################################
print_section_header "SECTION 4: DISPLAY & WAYLAND"

run_command "Session Type" "echo \$XDG_SESSION_TYPE"
run_command "Hyprland Version" "hyprctl version"
run_command "Monitor Configuration" "hyprctl monitors"
run_command "Active Workspaces" "hyprctl workspaces"
run_command "Hyprland Devices" "hyprctl devices"

print_subsection_header "Theme Information"
run_command "GTK Theme Settings" "gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo 'gsettings not available'"
run_command "Icon Theme" "gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || echo 'gsettings not available'"
run_command "Cursor Theme" "gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || echo 'gsettings not available'"
run_command "Qt Theme" "echo \$QT_QPA_PLATFORMTHEME"
run_command "Qt Style" "echo \$QT_STYLE_OVERRIDE"

if [[ -f "$HOME/.gtkrc-2.0" ]]; then
    print_file_content "$HOME/.gtkrc-2.0"
fi

if [[ -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
    print_file_content "$HOME/.config/gtk-4.0/settings.ini"
fi

run_command "Current Color Scheme (if set)" "echo \$GTK_THEME"
run_command "Installed GTK Themes" "ls /usr/share/themes/ ~/.themes/ ~/.local/share/themes/ 2>/dev/null | sort -u"
run_command "Installed Icon Themes" "ls /usr/share/icons/ ~/.icons/ ~/.local/share/icons/ 2>/dev/null | sort -u"

################################################################################
# SECTION 5: SHELL & ENVIRONMENT
################################################################################
print_section_header "SECTION 5: SHELL & ENVIRONMENT"

run_command "Current Shell" "echo \$SHELL"
run_command "Shell Version" "bash --version | head -n 1"
run_command "Environment Variables" "env | sort"
run_command "PATH" "echo \$PATH | tr ':' '\n'"

################################################################################
# SECTION 6: DOTFILES STRUCTURE
################################################################################
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
print_section_header "SECTION 7: CONFIGURATION FILES"

# Process all config directories
if [[ -d "$HOME/.config" ]]; then
    for config_dir in "$HOME/.config"/*; do
        if [[ -d "$config_dir" ]]; then
            dir_name=$(basename "$config_dir")
            process_directory_recursively "$config_dir" "Config: ~/.config/$dir_name/"
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
print_section_header "SECTION 10: NETWORK CONFIGURATION"

run_command "Network Interfaces" "ip addr"
run_command "Routing Table" "ip route"
run_command "NetworkManager Status" "nmcli device status"
run_command "Active Connections" "nmcli connection show --active"
run_command "DNS Configuration" "cat /etc/resolv.conf"

################################################################################
# SECTION 11: BOOT & SYSTEM LOGS
################################################################################
print_section_header "SECTION 11: BOOT & SYSTEM LOGS"

run_command "Last Boot Journal (last 100 lines)" "journalctl -b | tail -n 100"
run_command "Recent Errors" "journalctl -p err -b | tail -n 50"
run_command "Kernel Messages" "dmesg | tail -n 100"

################################################################################
# SECTION 12: NOTES FOR FUTURE ADDITIONS
################################################################################
print_section_header "SECTION 12: NOTES FOR FUTURE COMMAND ADDITIONS"

cat >> "$OUTPUT_FILE" << 'EOF'
This section serves as a reference for adding new commands to this script.

Format for adding new commands:
1. Identify the appropriate section (or create a new one)
2. Use: run_command "Description" "command_to_run"
3. For file contents: print_file_content "/path/to/file"
4. For directories: process_directory_recursively "/path/to/dir" "Section Title"

Common additions might include:
- Bluetooth: bluetoothctl list, bluetoothctl devices
- Audio: pactl list sinks, pactl list sources
- Power: upower -d, tlp-stat (if installed)
- Temperature: sensors
- Process list: ps aux
- Docker: docker ps, docker images (if installed)
- Python: pip list (if using)
- Node: npm list -g (if using)

EOF

################################################################################
# COMPLETION
################################################################################

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
echo -e "${GREEN}Ready to share with Claude!${NC}"
