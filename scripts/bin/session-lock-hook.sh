#!/usr/bin/env bash
# Kill monitoring dashboards, then launch hyprlock (single-instance).

set -euo pipefail

# Kill missioncenter GUI if running
pkill -x missioncenter 2>/dev/null || true

# Kill the btop instance you launch via foot
# (killing btop is enough; the foot window closes with it)
pkill -x btop 2>/dev/null || true

# Start hyprlock if it isn't already showing
pidof hyprlock >/dev/null || hyprlock
