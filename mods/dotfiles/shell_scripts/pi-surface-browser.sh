#!/usr/bin/env bash
# Opens a pi-surface page in terminal-browser, in one "pi-surface" tmux window
# per session: reuses the window and its browser when they exist, otherwise
# creates them. pi-surface runs this through its surface.browser setting.
set -euo pipefail

url="${1:?usage: pi-surface-browser.sh <url>}"
window_name="pi-surface"

default_browser() {
	if command -v open >/dev/null 2>&1; then
		exec open "$url"
	fi
	exec xdg-open "$url"
}

if [[ -z "${TMUX:-}" ]] || ! command -v terminal-browser >/dev/null 2>&1; then
	default_browser
fi

# The session of the pane pi runs in, not whichever session a client last used.
session="$(tmux display-message -p ${TMUX_PANE:+-t "$TMUX_PANE"} '#S')"

new_window() {
	exec tmux new-window -t "$session:" -n "$window_name" terminal-browser open "$url"
}

if ! command -v jq >/dev/null 2>&1; then
	new_window
fi

windows="$(tmux list-windows -t "$session" -F '#{window_id}	#{window_name}' | awk -F '\t' -v name="$window_name" '$2 == name { print $1 }')"
if [[ -z "$windows" ]]; then
	new_window
fi

# The browser in one of those windows, and the tab to reuse: one already on this
# page, else one on the same workflow page of an earlier server (its port and
# token change on restart), else none.
match="$(terminal-browser ls --all --json | jq -r \
	--arg session "$session" \
	--arg windows "$windows" \
	--arg url "$url" '
	def page: sub("^[a-z]+://[^/]+"; "") | split("/") | map(select(. != "")) | last;
	def local: test("^https?://(127\\.0\\.0\\.1|localhost)(:[0-9]+)?/");
	($windows | split("\n") | map("\($session):\(.)")) as $tabs
	| [.browsers[] | select(.pane.tab as $t | $tabs | index($t))] | first // empty
	| . as $b
	| (([$b.tabs[] | select(.url == $url)] + [$b.tabs[] | select((.url | local) and (.url | page) == ($url | page))]) | first | .id // "") as $tab
	| [$b.key, ($b.pane.tab | split(":") | last), ($tab | tostring)] | @tsv
')"

if [[ -z "$match" ]]; then
	# A pi-surface window whose browser has gone; leave it to the user and start fresh.
	new_window
fi

IFS=$'\t' read -r browser window tab <<<"$match"
if [[ -n "$tab" ]]; then
	terminal-browser action --browser "$browser" --tab "$tab" --follow -- eval "location.replace($(jq -rn --arg u "$url" '$u | tojson'))" >/dev/null
	# Clears the "agent is using this tab" overlay right away instead of after its timeout.
	terminal-browser action --browser "$browser" "done" >/dev/null
else
	terminal-browser new-tab --browser "$browser" "$url" >/dev/null
fi
tmux select-window -t "$window"
