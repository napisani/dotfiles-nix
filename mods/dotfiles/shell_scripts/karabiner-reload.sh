#!/usr/bin/env bash
# Restart Karabiner-Elements' services so they reload karabiner.json and drop
# runtime state such as a stale frontmost application or stuck variables.

set -euo pipefail

gui_domain="gui/$(id -u)"

echo "Restarting Karabiner-Elements..."

# The root core service grabs the keyboards, so it needs sudo.
echo "  → core service (root)"
sudo launchctl kickstart -k system/org.pqrs.service.daemon.Karabiner-Core-Service

for label in \
	org.pqrs.service.agent.Karabiner-Core-Service-rev2 \
	org.pqrs.service.agent.Karabiner-Console-User-Server; do
	echo "  → ${label#org.pqrs.service.agent.}"
	launchctl kickstart -k "$gui_domain/$label"
done

echo "✓ Karabiner restarted ($HOME/.config/karabiner/karabiner.json)"
