#!/usr/bin/env bash

# https://willhbr.net/2023/02/07/dismissable-popup-shell-in-tmux/
# this will display a persistent popup window in tmux that can be dismissed and reattached to

name="$1"
if [ -z "$name" ]; then
	name="scratch"
fi

session="_popup_$(tmux display -p '#S')_$name"

if ! tmux has -t "$session" 2>/dev/null; then
	session_id="$(tmux new-session -dP -s "$session" -F '#{session_id}')"
	tmux set-option -s -t "$session_id" key-table popup
	tmux set-option -s -t "$session_id" status off
	session="$session_id"
fi

exec tmux attach -t "$session" >/dev/null

