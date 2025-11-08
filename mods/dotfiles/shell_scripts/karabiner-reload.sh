#!/usr/bin/env bash
# Reload Karabiner-Elements configuration
# This script forces Karabiner to reload by restarting the console user server

set -e

echo "Reloading Karabiner-Elements configuration..."

# Restart the console user server to force config reload
echo "  → Restarting console user server..."
launchctl kickstart -k org.pqrs.service.agent.karabiner_console_user_server 2>/dev/null || \
    ( launchctl stop org.pqrs.service.agent.karabiner_console_user_server 2>/dev/null && \
      launchctl start org.pqrs.service.agent.karabiner_console_user_server 2>/dev/null ) || true

echo ""
echo "✓ Karabiner reload complete!"
echo ""
echo "  Note: The config file is symlinked from the dotfiles directory:"
echo "  ~/.config/karabiner/karabiner.json -> ~/.config/home-manager/mods/dotfiles/karabiner.json"
echo ""
echo "  If changes still aren't visible, fully restart Karabiner-Elements:"
echo "  osascript -e 'quit app \"Karabiner-Elements\"' && sleep 1 && open -a 'Karabiner-Elements'"
