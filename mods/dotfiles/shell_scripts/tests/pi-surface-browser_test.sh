#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
subject="$script_dir/../pi-surface-browser.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/pi-surface-browser-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Each stub logs its argv; tmux and terminal-browser answer from fixtures.
cat >"$tmp/tmux" <<'STUB'
#!/usr/bin/env bash
echo "tmux $*" >>"$TEST_LOG"
case "$1" in
display-message) echo '$1' ;;
list-windows) printf '%b' "$TEST_WINDOWS" ;;
list-panes) printf '%b' "$TEST_PANES" ;;
new-window) echo "@9" ;;
esac
STUB
cat >"$tmp/terminal-browser" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "ls" ]]; then
	cat "$TEST_BROWSERS"
	exit 0
fi
echo "terminal-browser $*" >>"$TEST_LOG"
STUB
cat >"$tmp/open" <<'STUB'
#!/usr/bin/env bash
echo "open $*" >>"$TEST_LOG"
STUB
chmod +x "$tmp/tmux" "$tmp/terminal-browser" "$tmp/open"

export PATH="$tmp:$PATH"
export TEST_LOG="$tmp/log"
export TEST_BROWSERS="$tmp/browsers.json"
url="http://127.0.0.1:5000/tok2/review/"

# terminal-browser prefixes pane.tab with an icon; the script must not depend on it.
browsers() {
	cat >"$TEST_BROWSERS" <<JSON
{ "browsers": [ { "key": "B1", "pane": { "tab": "$(printf '\357\220\230') main:@7", "pane": "$1" }, "tabs": [
  { "id": 1, "url": "https://example.com/" },
  { "id": 2, "url": "$2" }
] } ] }
JSON
}

check() {
	local name="$1" expected="$2"
	local actual
	actual="$(cat "$TEST_LOG")"
	if [[ "$actual" != "$expected" ]]; then
		printf 'FAIL %s\nexpected:\n%s\nactual:\n%s\n' "$name" "$expected" "$actual" >&2
		exit 1
	fi
	echo "ok: $name"
}

run() {
	: >"$TEST_LOG"
	"$subject" "${1:-$url}"
}

TMUX="" TEST_WINDOWS="" run
check "outside tmux it uses the default browser" "open $url"

export TMUX="/tmp/tmux-1/default,1,0" TMUX_PANE="%1"
# shellcheck disable=SC2016 # \$1 is the stub's literal tmux session id
lookup='tmux display-message -p -t %1 #{session_id}
tmux list-windows -t $1 -F #{window_id}	#{@pi_surface_page}'

browsers "%9" "$url"
TEST_WINDOWS='@1\t\n' run
check "with no window for the page it creates and marks one" \
	"$lookup
tmux new-window -P -F #{window_id} -t \$1: -n surface:review terminal-browser open $url
tmux set-option -w -t @9 @pi_surface_page review"

TEST_WINDOWS='@1\t\n@7\treview\n' TEST_PANES='%9\n' run
check "an earlier server's tab for the same page is reused" \
	"$lookup
tmux list-panes -t @7 -F #{pane_id}
terminal-browser action --browser B1 --tab 2 --follow -- eval location.replace(\"$url\")
terminal-browser action --browser B1 done
tmux select-window -t @7"

browsers "%9" "http://127.0.0.1:4000/tok1/review/#tab=files"
TEST_WINDOWS='@7\treview\n' TEST_PANES='%9\n' run
check "a tab's fragment does not hide its page" \
	"$lookup
tmux list-panes -t @7 -F #{pane_id}
terminal-browser action --browser B1 --tab 2 --follow -- eval location.replace(\"$url\")
terminal-browser action --browser B1 done
tmux select-window -t @7"

browsers "%9" "http://127.0.0.1:4000/tok1/forge/"
TEST_WINDOWS='@7\treview\n' TEST_PANES='%9\n' run
check "a window with no tab on the page gets a new tab" \
	"$lookup
tmux list-panes -t @7 -F #{pane_id}
terminal-browser new-tab --browser B1 $url
tmux select-window -t @7"

browsers "%9" "$url"
TEST_WINDOWS='@7\tforge\n' run
check "another page in the same session gets its own window" \
	"$lookup
tmux new-window -P -F #{window_id} -t \$1: -n surface:review terminal-browser open $url
tmux set-option -w -t @9 @pi_surface_page review"

# Another session's windows are not in this session's list-windows output, so a
# browser there is never considered.
browsers "%50" "$url"
TEST_WINDOWS='@1\t\n' run
check "another session's browser is not reused" \
	"$lookup
tmux new-window -P -F #{window_id} -t \$1: -n surface:review terminal-browser open $url
tmux set-option -w -t @9 @pi_surface_page review"

browsers "%50" "$url"
TEST_WINDOWS='@7\treview\n' TEST_PANES='%9\n' run
check "a window whose browser has gone is respawned" \
	"$lookup
tmux list-panes -t @7 -F #{pane_id}
tmux respawn-pane -k -t %9 terminal-browser open $url
tmux select-window -t @7"

echo "pi-surface browser: ok"
