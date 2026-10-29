#!/usr/bin/env bash
# Hard-reload Look: quit it and relaunch so it re-reads ~/.look. The index and
# clipboard history in Application Support are left alone.

# Look runs this script from its own action, so the work is detached; quitting
# Look would otherwise take the script down before it could relaunch.
(
  sleep 0.3
  osascript -e 'tell application "Look" to quit' >/dev/null 2>&1
  for _ in $(seq 30); do pgrep -qx Look || break; sleep 0.1; done
  # Without Automation permission the quit above is refused; fall back to SIGTERM.
  pgrep -qx Look && pkill -x Look
  for _ in $(seq 30); do pgrep -qx Look || break; sleep 0.1; done
  open -a /Applications/Look.app
) >/dev/null 2>&1 &
