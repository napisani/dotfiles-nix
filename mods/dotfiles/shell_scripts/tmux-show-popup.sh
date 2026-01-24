#!/usr/bin/env bash

# https://willhbr.net/2023/02/07/dismissable-popup-shell-in-tmux/
# this will display a persistent popup window in tmux that can be dismissed and reattached to

name="$1"
if [ -z "$name" ]; then
	name="scratch"
fi

current_path="$(tmux display-message -p '#{pane_current_path}')"

session="_popup_$(tmux display -p '#S')_$name"

if ! tmux has -t "$session" 2>/dev/null; then
	session_id="$(tmux new-session -dP -s "$session" -c "$current_path" -F '#{session_id}')"
	tmux set-option -s -t "$session_id" key-table popup
	tmux set-option -s -t "$session_id" status off
	session="$session_id"
fi

# used because of an issue with the golang version of proctmux where it somehow
# thinks it's already inside a tmux session, but if proctmux is not running, it doesn't
unset TMUX

exec tmux attach -t "$session" >/dev/null
