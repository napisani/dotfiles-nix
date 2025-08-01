#!/usr/bin/env bash

# Script to tag a tmux pane with a unique identifier

TAG="$1"
PANE_ID="$2"

# Clear tag from any pane that has the same tag
tmux list-panes -a -F "#{pane_id} #{@mcptag}" | while read id t; do
	if [ "$t" = "$TAG" ]; then
		tmux set-option -p -u -t "$id" @mcptag
	fi
done

# Set tag on current pane
tmux set-option -p -t "$PANE_ID" @mcptag "$TAG"
tmux display-message "Pane tagged as: $TAG"
