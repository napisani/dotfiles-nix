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
display-message) echo "main" ;;
list-windows) printf '%b' "$TEST_WINDOWS" ;;
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

browsers() {
	cat >"$TEST_BROWSERS" <<JSON
{ "browsers": [ { "key": "B1", "pane": { "tab": "$1", "pane": "%9" }, "tabs": [
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
	"$subject" "$url"
}

TMUX="" TEST_WINDOWS="" run
check "outside tmux it uses the default browser" "open $url"

export TMUX="/tmp/tmux-1/default,1,0" TMUX_PANE="%1"

TEST_WINDOWS='@1\tzsh\n' run
check "with no pi-surface window it creates one" \
	"tmux display-message -p -t %1 #S
tmux list-windows -t main -F #{window_id}	#{window_name}
tmux new-window -t main: -n pi-surface terminal-browser open $url"

browsers "main:@7" "http://127.0.0.1:4000/tok1/review/"
TEST_WINDOWS='@1\tzsh\n@7\tpi-surface\n' run
check "an earlier server's tab for the same workflow is reused" \
	"tmux display-message -p -t %1 #S
tmux list-windows -t main -F #{window_id}	#{window_name}
terminal-browser action --browser B1 --tab 2 --follow -- eval location.replace(\"$url\")
terminal-browser action --browser B1 done
tmux select-window -t @7"

browsers "main:@7" "http://127.0.0.1:4000/tok1/forge/"
TEST_WINDOWS='@7\tpi-surface\n' run
check "another workflow opens as a new tab in the same browser" \
	"tmux display-message -p -t %1 #S
tmux list-windows -t main -F #{window_id}	#{window_name}
terminal-browser new-tab --browser B1 $url
tmux select-window -t @7"

browsers "other:@7" "$url"
TEST_WINDOWS='@7\tpi-surface\n' run
check "a browser in another session's window is not this session's" \
	"tmux display-message -p -t %1 #S
tmux list-windows -t main -F #{window_id}	#{window_name}
tmux new-window -t main: -n pi-surface terminal-browser open $url"

echo "pi-surface browser: ok"
