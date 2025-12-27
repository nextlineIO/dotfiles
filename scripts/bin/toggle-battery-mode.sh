#!/bin/bash
# Script to toggle battery charge thresholds between conservation mode (40-80%) and full charge mode (0-100%)

# Notification settings
RID=9004  # Unique replace ID for battery mode notifications
TIMEOUT_MS=3000

# Check for notify-send
command -v notify-send >/dev/null || { echo "notify-send not found"; exit 1; }

# Read current thresholds
CURRENT_START=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold)
CURRENT_STOP=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold)

echo "Current battery thresholds: ${CURRENT_START}% - ${CURRENT_STOP}%"
echo ""

# Determine which mode we're in and toggle
if [ "$CURRENT_STOP" -eq 80 ]; then
    # Currently in conservation mode, switch to full charge
    NEW_START=0
    NEW_STOP=100
    MODE="Full Charge Mode"
    ICON="battery-full-charging-symbolic"
    NOTIFICATION_TITLE="Battery: Full Charge"
    NOTIFICATION_BODY="Charging to 100%"
    echo "Switching to Full Charge Mode (0-100%)..."
else
    # Currently in full charge mode, switch to conservation
    NEW_START=40
    NEW_STOP=80
    MODE="Conservation Mode"
    ICON="battery-level-80-symbolic"
    NOTIFICATION_TITLE="Battery: Conservation"
    NOTIFICATION_BODY="Charging limited to 80%"
    echo "Switching to Conservation Mode (40-80%)..."
fi

echo ""

# Backup current config
sudo cp /etc/tlp.conf /etc/tlp.conf.backup-$(date +%Y%m%d-%H%M%S)

# Update the thresholds in TLP config
sudo sed -i "s/^START_CHARGE_THRESH_BAT0=.*/START_CHARGE_THRESH_BAT0=${NEW_START}/" /etc/tlp.conf
sudo sed -i "s/^STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=${NEW_STOP}/" /etc/tlp.conf

# Apply the changes immediately
echo "Applying TLP settings..."
sudo tlp start

# Show new status
echo ""
echo "✓ Switched to ${MODE}"
echo ""
echo "New battery thresholds:"
echo "  Start charging at: $(cat /sys/class/power_supply/BAT0/charge_control_start_threshold)%"
echo "  Stop charging at:  $(cat /sys/class/power_supply/BAT0/charge_control_end_threshold)%"
echo ""
echo "Current battery status:"
echo "  Level: $(cat /sys/class/power_supply/BAT0/capacity)%"
echo "  State: $(cat /sys/class/power_supply/BAT0/status)"
echo ""
echo "Settings are permanent and will persist after reboot."

# Send desktop notification
notify-send -r "$RID" -t "$TIMEOUT_MS" -i "$ICON" \
  "$NOTIFICATION_TITLE" "$NOTIFICATION_BODY"
