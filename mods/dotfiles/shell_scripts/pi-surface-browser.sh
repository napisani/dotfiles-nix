#!/usr/bin/env bash
# Opens a pi-surface page in terminal-browser, in one tmux window per workflow
# page (review, forge, ...) per session: reuses that window and its browser when
# they exist, otherwise creates them. Other sessions and other pages never share
# a window. pi-surface runs this through its surface.browser setting.
set -euo pipefail

url="${1:?usage: pi-surface-browser.sh <url>}"

default_browser() {
	if command -v open >/dev/null 2>&1; then
		exec open "$url"
	fi
	exec xdg-open "$url"
}

if [[ -z "${TMUX:-}" ]] || ! command -v terminal-browser >/dev/null 2>&1; then
	default_browser
fi

# The workflow page is the last path segment, without query or fragment. A server
# restart changes the port and token but not the page, so it keys the window.
page="${url%%[#?]*}"
page="${page#*://}"
page="${page%/}"
page="${page##*/}"

# The session of the pane pi runs in, not whichever session a client last used.
# Its id, unlike its name, is safe to use as a target.
session="$(tmux display-message -p ${TMUX_PANE:+-t "$TMUX_PANE"} '#{session_id}')"

# Window names get renamed; this option marks the windows this script owns.
page_option="@pi_surface_page"

new_window() {
	local window
	window="$(tmux new-window -P -F '#{window_id}' -t "$session:" -n "surface:$page" terminal-browser open "$url")"
	tmux set-option -w -t "$window" "$page_option" "$page"
}

window="$(tmux list-windows -t "$session" -F "#{window_id}	#{$page_option}" | awk -F '\t' -v page="$page" '$2 == page { print $1; exit }')"
if [[ -z "$window" ]]; then
	new_window
	exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
	tmux select-window -t "$window"
	exit 0
fi

# The browser is the one in a pane of that window. The tab to reuse is one
# already on this page, else one on the same page of an earlier server, else none.
panes="$(tmux list-panes -t "$window" -F '#{pane_id}')"
match="$(terminal-browser ls --all --json | jq -r \
	--arg panes "$panes" \
	--arg url "$url" '
	def page: split("#")[0] | split("?")[0] | sub("^[a-z]+://[^/]+"; "") | split("/") | map(select(. != "")) | last;
	def local: test("^https?://(127\\.0\\.0\\.1|localhost)(:[0-9]+)?/");
	($panes | split("\n")) as $ids
	| [.browsers[] | select(.pane.pane as $p | $ids | index($p))] | first // empty
	| . as $b
	| (([$b.tabs[] | select(.url == $url)] + [$b.tabs[] | select((.url | local) and (.url | page) == ($url | page))]) | first | .id // "") as $tab
	| [$b.key, ($tab | tostring)] | @tsv
')"

if [[ -z "$match" ]]; then
	# The window outlived its browser; start one in its first pane.
	tmux respawn-pane -k -t "${panes%%$'\n'*}" terminal-browser open "$url"
	tmux select-window -t "$window"
	exit 0
fi

IFS=$'\t' read -r browser tab <<<"$match"
if [[ -n "$tab" ]]; then
	terminal-browser action --browser "$browser" --tab "$tab" --follow -- eval "location.replace($(jq -rn --arg u "$url" '$u | tojson'))" >/dev/null
	# Clears the "agent is using this tab" overlay right away instead of after its timeout.
	terminal-browser action --browser "$browser" "done" >/dev/null
else
	terminal-browser new-tab --browser "$browser" "$url" >/dev/null
fi
tmux select-window -t "$window"
