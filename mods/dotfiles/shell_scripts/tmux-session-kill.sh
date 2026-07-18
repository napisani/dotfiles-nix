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
		# Guarded with `|| true`: under pipefail, a failed git (e.g. the pane's
		# cwd has drifted outside any git repo) would otherwise propagate
		# through this pipeline and, since it's an unguarded assignment,
		# trigger `set -e` and abort the whole script here -- silently
		# skipping the fallback cleanup below and leaving the session alive.
		MAIN_REPO=$(git -C "$PANE_PATH" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||') || true

		if [ -n "$MAIN_REPO" ] && [ -f "$MAIN_REPO/.workmux.yaml" ]; then
			# Kill companion popup first (fast, keeps the picker responsive)
			kill_session_if_exists "_popup_${SESSION}_scratch"

			# `workmux remove --force` can be slow. Run it and the final
			# session cleanup fully detached (nohup, disowned, IO
			# redirected) so the picker isn't blocked waiting on it. It's
			# fine for the session to linger in the list until this
			# finishes in the background. (No setsid on macOS -- nohup +
			# disown is the portable equivalent for surviving the parent
			# script's exit.)
			nohup bash -c '
				cd "$1" && workmux remove --force "$2" >/dev/null 2>&1
				tmux kill-session -t "=$3" >/dev/null 2>&1 || true
			' _ "$MAIN_REPO" "$BRANCH" "$SESSION" </dev/null >/dev/null 2>&1 &
			disown
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
