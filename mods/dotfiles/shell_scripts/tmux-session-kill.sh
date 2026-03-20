#!/usr/bin/env bash
# tmux-session-kill.sh — Smart session removal with workmux awareness.
#
# Usage: tmux-session-kill.sh <session-name>
#
# Logic:
#   1. Popup session (_popup_*) → kill directly
#   2. Workmux worktree session (nerd font icon prefix) → workmux remove --force
#   3. Regular session → kill its popup companion first, then kill the session
#
# Designed to be called from fzf --bind inside a tmux display-popup.

set -euo pipefail

SESSION="${1:?Usage: tmux-session-kill.sh <session-name>}"

# Nerd font icon used by workmux as session prefix (U+F418, 3-byte UTF-8)
WORKMUX_PREFIX=$'\xef\x90\x98'

# ── Helper: kill a tmux session if it exists ──
kill_session_if_exists() {
	local name="$1"
	if tmux has-session -t "=$name" 2>/dev/null; then
		tmux kill-session -t "=$name"
	fi
}

# ── 1. Popup session → just kill it ──
if [[ "$SESSION" == _popup_* ]]; then
	kill_session_if_exists "$SESSION"
	exit 0
fi

# ── 2. Workmux worktree session (icon-prefixed) ──
if [[ "$SESSION" == "${WORKMUX_PREFIX}"* ]]; then
	# Extract branch name: strip the icon prefix
	BRANCH="${SESSION#"${WORKMUX_PREFIX}"}"
	# Trim any leading whitespace the icon might leave
	BRANCH="${BRANCH#"${BRANCH%%[![:space:]]*}"}"

	# Find the worktree directory from a pane in this session
	PANE_PATH=$(tmux list-panes -t "=$SESSION" -F '#{pane_current_path}' 2>/dev/null | head -1)

	if [ -n "$PANE_PATH" ]; then
		# The pane path is inside the worktree. The main repo is the git
		# common dir's parent (worktree -> __worktrees/branch, main repo is sibling).
		MAIN_REPO=$(git -C "$PANE_PATH" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||')

		if [ -n "$MAIN_REPO" ] && [ -f "$MAIN_REPO/.workmux.yaml" ]; then
			# Kill companion popup first
			kill_session_if_exists "_popup_${SESSION}_scratch"
			# Use workmux remove from the main repo directory
			(cd "$MAIN_REPO" && workmux remove --force "$BRANCH") 2>/dev/null || true
			# Ensure session is gone even if workmux didn't fully clean up
			kill_session_if_exists "$SESSION"
			exit 0
		fi
	fi

	# Fallback: kill popup + session directly if workmux detection failed
	kill_session_if_exists "_popup_${SESSION}_scratch"
	kill_session_if_exists "$SESSION"
	exit 0
fi

# ── 3. Regular session → kill popup companion, then kill session ──
kill_session_if_exists "_popup_${SESSION}_scratch"
kill_session_if_exists "$SESSION"
exit 0
